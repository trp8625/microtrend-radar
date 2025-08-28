# Microtrend Radar 

**Street‑to‑Store Fashion Signals**: a SQL‑forward project that detects neighborhood‑level (SoHo & Williamsburg) fashion microtrends from resale listings and related signals (weather, runway).

---

## 1) Problem Statement & Research Questions

**Goal:** Use SQL to reveal **emerging fashion microtrends** and answer:

- **RQ1 — Trend Velocity:** Which terms (e.g., *ballet flats*, *metallic*, *neon green*) are accelerating **by neighborhood** right now?
- **RQ2 — Price Momentum:** Are prices for a term rising or falling in the last week vs the prior week?
- **RQ3 — Weather Lift:** Do rainy days amplify or suppress certain trends?

---

## 2) Data Inputs (synthetic for demo)

- **Listings (400 rows)**: platform, title, brand, price, timestamp, lon/lat, `tags` (JSON array).  
- **Neighborhoods**: SoHo & Williamsburg polygons (coarse demo shapes).  
- **Terms**: canonical tags plus synonyms (e.g., `metallic` ⇔ `chrome`, `silver`, `foil`).  
- **Weather (daily)**: clear/rain flags across the time window.  

---

## 3) Metric Definitions

- **Trend Velocity (per neighborhood, term)**  
  d7 = 7‑day rolling sum; prev7 = previous 7‑day rolling sum; `velocity = (d7 - prev7) / prev7`.
- **Price Momentum (per term)**  
  Ratio of 7‑day rolling **median** price vs prior 7‑day median.
- **Weather Lift (per term)**  
  Mean frequency on rainy days ÷ overall mean frequency.

---

## 4) Approach 

1. **Normalize tags → canonical terms** via a synonyms table.  
2. **Geo‑join** listings into neighborhoods using lon/lat and polygons (PostGIS).  
3. **Daily aggregation** and **window functions** to compute:
   - **Trend Velocity** per (neighborhood, term): 7‑day sum vs previous 7‑day sum.  
   - **Price Momentum** per term: 7‑day median price vs previous 7‑day median.  
   - **Weather Lift** per term: mean frequency on rainy days ÷ overall mean.  
4. **Materialized Views** for fast dashboards (Metabase‑ready).  
5. **Batch export** of results to `/outputs/*.csv` for GitHub transparency.

---

## 5) Key Results (from the 400‑row demo run)

**Latest day analyzed:** **2025‑08‑09**

In short: 

Williamsburg: 
- Ballet flats are very popular; weekly mentions rose from 1 to 6 (+500% jump). 
- Neon green grew a bit (17 to 19, +11.8%)
  
SoHo: 
- Ballet flats are also popular but more modestly; rose from 3 to 5 (+66.7%)
- Neon green fell sharply (21 to 7, −66.7%)
- Metallic items grew slightly (from 7 to 8, +14.3%)

Prices are moving differently than volume: 
- Neon green shows positive price momentum: the 7-day median price is 23.5% higher than the prior week, suggesting buyers are willing to pay more.
- Metallic and ballet flats show negative price momentum (−11.5% and −25.0% respectively), which means more listings or interest without higher prices (consistent with accessible, fast-moving trends)

Weather had little impact on term frequency in this window: 
- Rain-day activity was roughly the same as average

### 5.1 Trend Velocity (d7 vs prev7) — top items
- **Williamsburg · ballet flats** — d7 = 6, prev7 = 1 → **+500%**
- **SoHo · ballet flats** — d7 = 5, prev7 = 3 → **+66.7%**
- **SoHo · metallic** — d7 = 8, prev7 = 7 → **+14.3%**
- **Williamsburg · neon green** — d7 = 19, prev7 = 17 → **+11.8%**
- **SoHo · neon green** — d7 = 7, prev7 = 21 → **−66.7%**

> Source: `outputs/velocity_latest.csv`

### 5.2 Price Momentum (7‑day median vs prior 7‑day) — by term
- **neon green:** **+23.5%** (74.82 → 60.59)  
- **metallic:** −11.5% (68.35 → 77.20)  
- **ballet flats:** −25.0% (89.83 → 119.83)

> Source: `outputs/price_momentum_latest.csv`

### 5.3 Weather Lift (rain vs average) — by term
- **neon green:** ~**1.03×**  
- **metallic:** ~0.98×  
- **ballet flats:** ~0.96×

> Source: `outputs/weather_lift.csv`

---

## 6) Repository Layout

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
├─ outputs/                            # Computed results (CSV)
│  ├─ velocity_latest.csv
│  ├─ price_momentum_latest.csv
│  ├─ weather_lift.csv
├─ docker-compose.yml                  # Postgres + PostGIS + Metabase + Adminer
├─ .env.example
```


