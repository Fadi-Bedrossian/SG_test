CREATE TABLE IF NOT EXISTS items (
  id         SERIAL PRIMARY KEY,
  title      VARCHAR(200) NOT NULL,
  done       BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_items_created_at ON items (created_at DESC);
