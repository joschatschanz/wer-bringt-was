-- Wer bringt was? — Supabase Schema
-- Run this in your Supabase SQL editor

CREATE TABLE events (
  id            TEXT PRIMARY KEY,
  admin_token   TEXT NOT NULL,
  title         TEXT NOT NULL,
  date          TEXT,
  location      TEXT,
  note          TEXT,
  created_at    TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE items (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id        TEXT REFERENCES events(id) ON DELETE CASCADE,
  name            TEXT NOT NULL,
  quantity_total  INTEGER,
  created_by      TEXT,
  created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE claims (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id     UUID REFERENCES items(id) ON DELETE CASCADE,
  guest_name  TEXT NOT NULL,
  amount      INTEGER NOT NULL DEFAULT 1,
  claimed_at  TIMESTAMPTZ DEFAULT now()
);

-- Row Level Security
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE items  ENABLE ROW LEVEL SECURITY;
ALTER TABLE claims ENABLE ROW LEVEL SECURITY;

-- Everyone can read
CREATE POLICY "public read events" ON events FOR SELECT USING (true);
CREATE POLICY "public read items"  ON items  FOR SELECT USING (true);
CREATE POLICY "public read claims" ON claims FOR SELECT USING (true);

-- Anyone can insert events (creation happens server-side)
CREATE POLICY "public insert events" ON events FOR INSERT WITH CHECK (true);
CREATE POLICY "public insert items"  ON items  FOR INSERT WITH CHECK (true);
CREATE POLICY "public insert claims" ON claims FOR INSERT WITH CHECK (true);

-- Delete (admin_token check is done server-side, but we allow deletes for the service role)
CREATE POLICY "public delete items"  ON items  FOR DELETE USING (true);
CREATE POLICY "public delete claims" ON claims FOR DELETE USING (true);

-- Update for events (admin edit)
CREATE POLICY "public update events" ON events FOR UPDATE USING (true);
