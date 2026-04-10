CREATE SCHEMA IF NOT EXISTS demo;

CREATE TABLE IF NOT EXISTS demo.accounts (
  id bigint PRIMARY KEY,
  name text NOT NULL,
  balance numeric(12,2) NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO demo.accounts (id, name, balance)
VALUES
  (1, 'Alice', 1000.00),
  (2, 'Bob', 500.00)
ON CONFLICT (id) DO UPDATE
SET
  name = EXCLUDED.name,
  balance = EXCLUDED.balance,
  updated_at = now();

TABLE demo.accounts;
