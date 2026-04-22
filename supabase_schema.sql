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

-- ─────────────────────────────────────────────────────────────────────────────
-- Atomic claim function — run once in Supabase SQL editor
-- Uses SELECT FOR UPDATE to lock the row and prevent race conditions when
-- multiple users claim the same item simultaneously.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION claim_item(
  p_item_id    UUID,
  p_guest_name TEXT,
  p_amount     INTEGER
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER   -- runs as owner so FOR UPDATE lock works past RLS
AS $$
DECLARE
  v_qty_total  INTEGER;
  v_claimed    INTEGER;
  v_left       INTEGER;
  v_count      INTEGER;
BEGIN
  -- Lock this item row; prevents two concurrent claims from both passing the check
  SELECT quantity_total INTO v_qty_total
  FROM items WHERE id = p_item_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'item_not_found');
  END IF;

  -- No quantity = single-claim item
  IF v_qty_total IS NULL THEN
    SELECT COUNT(*) INTO v_count FROM claims WHERE item_id = p_item_id;
    IF v_count > 0 THEN
      RETURN jsonb_build_object('success', false, 'error', 'already_claimed');
    END IF;
    INSERT INTO claims (item_id, guest_name, amount)
    VALUES (p_item_id, p_guest_name, 1);
    RETURN jsonb_build_object('success', true);
  END IF;

  -- Quantity item: check remaining
  SELECT COALESCE(SUM(amount), 0) INTO v_claimed FROM claims WHERE item_id = p_item_id;
  v_left := v_qty_total - v_claimed;

  IF p_amount > v_left THEN
    RETURN jsonb_build_object('success', false, 'remaining', v_left);
  END IF;

  INSERT INTO claims (item_id, guest_name, amount)
  VALUES (p_item_id, p_guest_name, p_amount);

  RETURN jsonb_build_object('success', true);
END;
$$;

-- Allow the anon key to call this function
GRANT EXECUTE ON FUNCTION claim_item TO anon;
