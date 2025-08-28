DROP MATERIALIZED VIEW IF EXISTS mv_hits CASCADE;
CREATE MATERIALIZED VIEW mv_hits AS
WITH tagged AS (
  SELECT DATE_TRUNC('day', l.created_at)::date AS day, n.name AS neighborhood,
         COALESCE(t.term, j.tag) AS term
  FROM listings l
  JOIN neighborhoods n ON ST_Contains(n.geom, l.geom)
  JOIN LATERAL jsonb_array_elements_text(l.tags) j(tag) ON TRUE
  LEFT JOIN terms t
    ON j.tag = t.term
    OR j.tag = ANY(SELECT jsonb_array_elements_text(t.synonyms))
)
SELECT neighborhood, term, day, COUNT(*) AS cnt
FROM tagged GROUP BY 1,2,3;

DROP MATERIALIZED VIEW IF EXISTS mv_velocity CASCADE;
CREATE MATERIALIZED VIEW mv_velocity AS
WITH roll AS (
  SELECT neighborhood, term, day,
    SUM(cnt) OVER (PARTITION BY neighborhood, term ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS d7,
    SUM(cnt) OVER (PARTITION BY neighborhood, term ORDER BY day ROWS BETWEEN 13 PRECEDING AND 7 PRECEDING) AS prev7
  FROM mv_hits
)
SELECT neighborhood, term, day, d7, prev7,
       CASE WHEN prev7 > 0 THEN (d7 - prev7)::float/prev7 ELSE NULL END AS velocity
FROM roll;

DROP MATERIALIZED VIEW IF EXISTS mv_price_momentum CASCADE;
CREATE MATERIALIZED VIEW mv_price_momentum AS
WITH base AS (
  SELECT DATE_TRUNC('day', created_at)::date AS day, COALESCE(t.term, j.tag) AS term, price
  FROM listings l
  JOIN LATERAL jsonb_array_elements_text(l.tags) j(tag) ON TRUE
  LEFT JOIN terms t
    ON j.tag = t.term OR j.tag = ANY(SELECT jsonb_array_elements_text(t.synonyms))
), d AS (
  SELECT term, day,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price)
      OVER (PARTITION BY term ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS med7,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price)
      OVER (PARTITION BY term ORDER BY day ROWS BETWEEN 13 PRECEDING AND 7 PRECEDING) AS med_prev7
  FROM base
)
SELECT term, day, med7, med_prev7,
       CASE WHEN med_prev7 > 0 THEN (med7 - med_prev7)/med_prev7 ELSE NULL END AS momentum
FROM d;

DROP MATERIALIZED VIEW IF EXISTS mv_term_spikes CASCADE;
CREATE MATERIALIZED VIEW mv_term_spikes AS
WITH d AS (
  SELECT term, day, SUM(cnt) OVER (PARTITION BY term ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS d7
  FROM (SELECT term, day, SUM(cnt) AS cnt FROM mv_hits GROUP BY 1,2) s
), baseline AS (
  SELECT term, AVG(d7) AS avg_d7 FROM d GROUP BY term
), spike_days AS (
  SELECT d.term, d.day FROM d JOIN baseline b USING(term) WHERE d.d7 >= 3 * COALESCE(b.avg_d7, 1)
)
SELECT term, MIN(day) AS first_spike_day FROM spike_days GROUP BY term;

DROP MATERIALIZED VIEW IF EXISTS mv_runway_lag CASCADE;
CREATE MATERIALIZED VIEW mv_runway_lag AS
SELECT r.designer, r.season, j.term,
       (SELECT first_spike_day FROM mv_term_spikes s WHERE s.term=j.term) AS first_spike_day,
       CASE WHEN (SELECT first_spike_day FROM mv_term_spikes s WHERE s.term=j.term) IS NOT NULL
            THEN (SELECT first_spike_day FROM mv_term_spikes s WHERE s.term=j.term) - r.show_date
            ELSE NULL END AS days_to_spike
FROM runway_looks r
JOIN LATERAL jsonb_array_elements_text(r.tags) j(term) ON TRUE;

DROP MATERIALIZED VIEW IF EXISTS mv_weather_lift CASCADE;
CREATE MATERIALIZED VIEW mv_weather_lift AS
WITH daily AS (
  SELECT DATE_TRUNC('day', l.created_at)::date AS day, COALESCE(t.term, j.tag) AS term, COUNT(*) AS freq
  FROM listings l
  JOIN LATERAL jsonb_array_elements_text(l.tags) j(tag) ON TRUE
  LEFT JOIN terms t ON j.tag = t.term OR j.tag = ANY(SELECT jsonb_array_elements_text(t.synonyms))
  GROUP BY 1,2
)
SELECT x.term,
  AVG(CASE WHEN w.weather='rain' THEN x.freq::float END) / NULLIF(AVG(x.freq::float),0) AS rain_lift
FROM daily x JOIN daily_weather w ON w.date = x.day
GROUP BY x.term;
