CREATE EXTENSION IF NOT EXISTS postgis;
CREATE TABLE IF NOT EXISTS neighborhoods (id SERIAL PRIMARY KEY, name TEXT UNIQUE, geom GEOMETRY(POLYGON,4326));
CREATE INDEX IF NOT EXISTS idx_nbh_geom ON neighborhoods USING GIST (geom);
CREATE TABLE IF NOT EXISTS terms (term TEXT PRIMARY KEY, synonyms JSONB DEFAULT '[]'::jsonb);
CREATE INDEX IF NOT EXISTS idx_terms_syn ON terms USING GIN (synonyms jsonb_path_ops);
CREATE TABLE IF NOT EXISTS listings (
  listing_id TEXT PRIMARY KEY, platform TEXT, title TEXT, brand TEXT, color TEXT,
  price NUMERIC, created_at TIMESTAMPTZ, geom GEOMETRY(POINT,4326), tags JSONB DEFAULT '[]'::jsonb
);
CREATE INDEX IF NOT EXISTS idx_list_geom ON listings USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_list_tags ON listings USING GIN (tags jsonb_path_ops);
CREATE INDEX IF NOT EXISTS idx_list_created ON listings (created_at);
CREATE TABLE IF NOT EXISTS runway_looks (look_id TEXT PRIMARY KEY, designer TEXT, season TEXT, show_date DATE, tags JSONB DEFAULT '[]'::jsonb);
CREATE INDEX IF NOT EXISTS idx_runway_tags ON runway_looks USING GIN (tags jsonb_path_ops);
CREATE TABLE IF NOT EXISTS store_drops (sku TEXT PRIMARY KEY, brand TEXT, category TEXT, drop_date DATE, price NUMERIC);
CREATE TABLE IF NOT EXISTS daily_weather (date DATE PRIMARY KEY, weather TEXT, tmin NUMERIC, tmax NUMERIC, precip NUMERIC);
