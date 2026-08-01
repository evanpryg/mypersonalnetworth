-- SUPABASE SCHEMA FOR INVESTMENT TRACKER & MONEY MANAGEMENT
-- Standard PostgreSQL lowercase schema for maximum compatibility.

-- 1. targets Table
CREATE TABLE IF NOT EXISTS targets (
  targetid VARCHAR PRIMARY KEY,
  targetname VARCHAR NOT NULL,
  targetamount NUMERIC NOT NULL,
  targetcurrency VARCHAR DEFAULT 'IDR',
  startdate DATE,
  notes TEXT
);

-- 2. transactions Table (Investment Tracker)
CREATE TABLE IF NOT EXISTS transactions (
  id SERIAL PRIMARY KEY,
  timestamp TIMESTAMPTZ DEFAULT NOW(),
  date DATE NOT NULL,
  platform VARCHAR NOT NULL,
  sector VARCHAR NOT NULL,
  asset VARCHAR NOT NULL,
  transactiontype VARCHAR NOT NULL,
  amountidr NUMERIC NOT NULL,
  notes TEXT,
  status VARCHAR DEFAULT 'Active'
);

-- 2b. Backlink from an investment row to the money-management transfer that
--     created it, so deleting or editing the transfer can follow it.
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS mm_tx_id INTEGER;
CREATE INDEX IF NOT EXISTS idx_transactions_mm_tx_id ON transactions(mm_tx_id);

-- 3. portfolio Table
CREATE TABLE IF NOT EXISTS portfolio (
  platform VARCHAR NOT NULL,
  sector VARCHAR NOT NULL,
  asset VARCHAR NOT NULL,
  currentvalueidr NUMERIC NOT NULL,
  PRIMARY KEY (platform, sector, asset)
);

-- 4. settings Table
CREATE TABLE IF NOT EXISTS settings (
  id SERIAL PRIMARY KEY,
  key VARCHAR NOT NULL,
  value VARCHAR NOT NULL
);

-- 5. allocation_targets Table
CREATE TABLE IF NOT EXISTS allocation_targets (
  sector VARCHAR PRIMARY KEY,
  targetpercent NUMERIC NOT NULL
);

-- 6. mm_accounts Table (Money Management Accounts)
CREATE TABLE IF NOT EXISTS mm_accounts (
  accountid VARCHAR PRIMARY KEY,
  name VARCHAR NOT NULL,
  icon VARCHAR DEFAULT '💳',
  initialbalance NUMERIC NOT NULL,
  "order" INTEGER DEFAULT 999,
  showondashboard VARCHAR DEFAULT 'true',
  status VARCHAR DEFAULT 'Active'
);

-- 7. mm_transactions Table (Money Management Transactions)
CREATE TABLE IF NOT EXISTS mm_transactions (
  id SERIAL PRIMARY KEY,
  timestamp TIMESTAMPTZ DEFAULT NOW(),
  date DATE NOT NULL,
  type VARCHAR NOT NULL,
  account VARCHAR NOT NULL,
  accountto VARCHAR,
  category VARCHAR,
  subcategory VARCHAR,
  amount NUMERIC NOT NULL,
  notes TEXT,
  status VARCHAR DEFAULT 'Active'
);

-- 8. mm_categories Table
CREATE TABLE IF NOT EXISTS mm_categories (
  id SERIAL PRIMARY KEY,
  type VARCHAR NOT NULL,
  category VARCHAR NOT NULL,
  subcategory VARCHAR,
  status VARCHAR DEFAULT 'Active'
);

-- 9. mm_allocation Table
CREATE TABLE IF NOT EXISTS mm_allocation (
  category VARCHAR PRIMARY KEY,
  percent NUMERIC NOT NULL,
  icon VARCHAR,
  color VARCHAR
);

-- 10. mm_summary Table — archived years.
-- Older years are collapsed to one row per month/type/category/subcategory
-- (see migrations/001_archive_2025.sql) so the ledger stops growing while
-- History and Insight can still chart them.
CREATE TABLE IF NOT EXISTS mm_summary (
  id           SERIAL PRIMARY KEY,
  period_year  INTEGER NOT NULL,
  period_month INTEGER NOT NULL,
  type         VARCHAR NOT NULL,
  category     VARCHAR NOT NULL DEFAULT '',
  subcategory  VARCHAR NOT NULL DEFAULT '',
  amount       NUMERIC NOT NULL,
  tx_count     INTEGER NOT NULL DEFAULT 0,
  UNIQUE (period_year, period_month, type, category, subcategory)
);
CREATE INDEX IF NOT EXISTS idx_mm_summary_year ON mm_summary(period_year);

-- Create Indexes for performance optimization
CREATE INDEX IF NOT EXISTS idx_transactions_status ON transactions(status);
CREATE INDEX IF NOT EXISTS idx_mm_transactions_status ON mm_transactions(status);
CREATE INDEX IF NOT EXISTS idx_mm_categories_status ON mm_categories(status);
CREATE INDEX IF NOT EXISTS idx_mm_accounts_status ON mm_accounts(status);

-- Insert default configurations
INSERT INTO settings (key, value) VALUES
  ('Platform', 'Ajaib'),
  ('Platform', 'Bibit'),
  ('Platform', 'Binance'),
  ('Sector', 'Stocks'),
  ('Sector', 'Crypto'),
  ('Sector', 'Mutual Funds'),
  ('Sector', 'Gold'),
  ('Sector', 'Bonds'),
  ('Sector', 'Cash'),
  ('TransactionType', 'Deposit'),
  ('TransactionType', 'Buy'),
  ('TransactionType', 'Sell'),
  ('TransactionType', 'Withdraw')
ON CONFLICT DO NOTHING;

INSERT INTO targets (targetid, targetname, targetamount, targetcurrency, startdate, notes)
VALUES ('T001', 'First 100 Million', 100000000, 'IDR', CURRENT_DATE, 'My Networth Target')
ON CONFLICT DO NOTHING;

INSERT INTO mm_allocation (category, percent, icon, color) VALUES
  ('Living', 50, '🏠', '#10b981'),
  ('Playing', 20, '🎮', '#f59e0b'),
  ('Alms', 10, '🤲', '#ec4899'),
  ('Invest', 20, '📈', '#3b82f6')
ON CONFLICT DO NOTHING;

-- Disable Row Level Security (RLS) for the initial bootstrap.
--
-- WARNING: leaving it this way makes the whole database readable and
-- writable by anyone who opens the published page, because the anon key is
-- part of the bundle. Once the app is up and you can log in, apply
-- migrations/002_enable_rls.sql to turn RLS back on and lock the tables to
-- your own account.
ALTER TABLE targets DISABLE ROW LEVEL SECURITY;
ALTER TABLE transactions DISABLE ROW LEVEL SECURITY;
ALTER TABLE portfolio DISABLE ROW LEVEL SECURITY;
ALTER TABLE settings DISABLE ROW LEVEL SECURITY;
ALTER TABLE allocation_targets DISABLE ROW LEVEL SECURITY;
ALTER TABLE mm_accounts DISABLE ROW LEVEL SECURITY;
ALTER TABLE mm_transactions DISABLE ROW LEVEL SECURITY;
ALTER TABLE mm_categories DISABLE ROW LEVEL SECURITY;
ALTER TABLE mm_allocation DISABLE ROW LEVEL SECURITY;
ALTER TABLE mm_summary DISABLE ROW LEVEL SECURITY;
