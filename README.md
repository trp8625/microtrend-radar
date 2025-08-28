# Microtrend Radar (SQL‑first)

**Street‑to‑Store Fashion Signals** — a reproducible, SQL‑forward project that detects neighborhood‑level fashion microtrends from resale listings and related signals (weather, runway).

---

## 1) Problem Statement & Research Questions

**Goal:** Use simple, scalable SQL to reveal **emerging fashion microtrends** and answer:

- **RQ1 — Trend Velocity:** Which terms (e.g., *ballet flats*, *metallic*, *neon green*) are accelerating **by neighborhood** right now?
- **RQ2 — Price Momentum:** Are prices for a term rising or falling in the last week vs the prior week?
- **RQ3 — Weather Lift:** Do rainy days amplify or suppress certain trends?
- **RQ4 — Runway → Resale Lag:** How long after a runway show do we observe a measurable spike in resale interest?

The project favors **Postgres + PostGIS** for local work, with **BigQuery** SQL equivalents for serverless scale.

---

## 2) Data Inputs (synthetic for demo)

- **Listings (400 rows)** — platform, title, brand, price, timestamp, lon/lat, `tags` (JSON array).  
- **Neighborhoods** — SoHo & Williamsburg polygons (coarse demo shapes).  
- **Terms** — canonical tags plus synonyms (e.g., `metallic` ⇔ `chrome`, `silver`, `foil`).  
- **Weather (daily)** — clear/rain flags across the time window.  
- **Runway Looks (toy)** — designer, season, show date, tags.

> Replace with your real feeds when ready; schema is intentionally light-weight.

---

## 3) Approach (high level)

1. **Normalize tags → canonical terms** via a synonyms table.  
2. **Geo‑join** listings into neighborhoods using lon/lat and polygons (PostGIS).  
3. **Daily aggregation** and **window functions** to compute:
   - **Trend Velocity** per (neighborhood, term): 7‑day sum vs previous 7‑day sum.  
   - **Price Momentum** per term: 7‑day median price vs previous 7‑day median.  
   - **Weather Lift** per term: mean frequency on rainy days ÷ overall mean.  
   - **Runway Lag** per term: first 7‑day spike ≥ **3×** baseline minus show date.
4. **Materialized Views** for fast dashboards (Metabase‑ready).  
5. **Batch export** of results to `/outputs/*.csv` for GitHub transparency.

---

## 4) Key Results (from the 400‑row demo run)

**Latest day analyzed:** **2025‑08‑09**

### 4.1 Trend Velocity (d7 vs prev7) — top items
- **Williamsburg · ballet flats** — d7 = 6, prev7 = 1 → **+500%**
- **SoHo · ballet flats** — d7 = 5, prev7 = 3 → **+66.7%**
- **SoHo · metallic** — d7 = 8, prev7 = 7 → **+14.3%**
- **Williamsburg · neon green** — d7 = 19, prev7 = 17 → **+11.8%**
- **SoHo · neon green** — d7 = 7, prev7 = 21 → **−66.7%**

> Source: `outputs/velocity_latest.csv`

### 4.2 Price Momentum (7‑day median vs prior 7‑day) — by term
- **neon green:** **+23.5%** (74.82 → 60.59)  
- **metallic:** −11.5% (68.35 → 77.20)  
- **ballet flats:** −25.0% (89.83 → 119.83)

> Source: `outputs/price_momentum_latest.csv`

### 4.3 Weather Lift (rain vs average) — by term
- **neon green:** ~**1.03×**  
- **metallic:** ~0.98×  
- **ballet flats:** ~0.96×

> Source: `outputs/weather_lift.csv`

### 4.4 Runway → Resale Lag
Using a **3× baseline** spike rule in this window, no term crossed the threshold → lag not established.  
(With **2×** or a longer horizon, lags typically emerge.)

> Source: `outputs/runway_lag.csv`

---

## 5) Repository Layout

```
microtrend-radar-sql/
├─ db/
│  └─ init/
│     └─ 01_schema.sql                # Tables + PostGIS indexes
├─ sql/
│  └─ materialized_views.sql          # Velocity, momentum, weather, runway lag
├─ data/                               # Demo CSVs (synthetic)
│  ├─ listings_400.csv
│  ├─ neighborhoods_sample.csv
│  ├─ terms_full.csv
│  ├─ daily_weather_full.csv
│  └─ runway_looks_more.csv
├─ outputs/                            # Computed results (CSV)
│  ├─ velocity_latest.csv
│  ├─ price_momentum_latest.csv
│  ├─ weather_lift.csv
│  └─ runway_lag.csv
├─ docker-compose.yml                  # Postgres + PostGIS + Metabase + Adminer
├─ .env.example
├─ LICENSE
└─ README.md
```
