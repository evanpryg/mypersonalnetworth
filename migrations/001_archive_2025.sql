-- ============================================================
-- 001 — Arsipkan detail 2025 jadi ringkasan per kategori
-- ============================================================
-- Jalankan SEKALI di Supabase → SQL Editor → New query → Run.
-- Seluruh skrip ada dalam satu transaksi: kalau ada satu langkah
-- yang gagal, TIDAK ADA perubahan sama sekali yang tersimpan.
--
-- Yang dilakukan:
--   1. Tambah kolom transactions.mm_tx_id (penghubung transfer↔investasi)
--   2. Buat tabel mm_summary
--   3. Ringkas transaksi 2025 -> mm_summary (per bulan/tipe/kategori/subkategori)
--   4. Gulung net 2025 tiap akun ke mm_accounts.initialbalance
--   5. Hapus 490 baris detail 2025
--
-- Langkah 4 WAJIB: saldo dihitung dari initialbalance + semua transaksi,
-- jadi tanpa ini saldo akan meleset jutaan begitu detailnya hilang.
-- ============================================================

BEGIN;

-- ---------- 0. Pengaman: jangan jalan dua kali ----------
-- Kalau detail 2025 sudah tidak ada, berarti migrasi ini sudah pernah jalan.
-- Tanpa cek ini, jalan kedua akan menghapus mm_summary 2025 lalu mengisinya
-- dari tabel yang sudah kosong — ringkasan Anda hilang.
DO $$
DECLARE n INTEGER;
BEGIN
  SELECT COUNT(*) INTO n FROM mm_transactions
  WHERE date BETWEEN DATE '2025-01-01' AND DATE '2025-12-31';
  IF n = 0 THEN
    RAISE EXCEPTION 'Tidak ada transaksi 2025 untuk diarsipkan — migrasi ini sudah pernah dijalankan. Dibatalkan, tidak ada data yang berubah.';
  END IF;
  RAISE NOTICE 'Mengarsipkan % transaksi 2025...', n;
END $$;

-- ---------- 1. Penghubung baris investasi ke baris money-management ----------
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS mm_tx_id INTEGER;
CREATE INDEX IF NOT EXISTS idx_transactions_mm_tx_id ON transactions(mm_tx_id);

-- ---------- 2. Tabel ringkasan ----------
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
ALTER TABLE mm_summary DISABLE ROW LEVEL SECURITY;

-- ---------- 3. Ringkas 2025 ----------
-- Aman diulang: baris 2025 lama dibuang dulu.
DELETE FROM mm_summary WHERE period_year = 2025;

INSERT INTO mm_summary (period_year, period_month, type, category, subcategory, amount, tx_count)
SELECT EXTRACT(YEAR  FROM date)::int,
       EXTRACT(MONTH FROM date)::int,
       type,
       COALESCE(category, ''),
       COALESCE(subcategory, ''),
       SUM(amount),
       COUNT(*)
FROM mm_transactions
WHERE date BETWEEN DATE '2025-01-01' AND DATE '2025-12-31'
  AND COALESCE(status, 'Active') <> 'Deleted'
GROUP BY 1, 2, 3, 4, 5;

-- ---------- 4. Gulung net 2025 ke saldo awal akun ----------
-- Uang keluar dari `account`, masuk ke `accountto` (transfer saja).
CREATE TEMP TABLE _delta2025 ON COMMIT DROP AS
SELECT acct, SUM(amt) AS net
FROM (
  SELECT account AS acct,
         CASE type WHEN 'Income'   THEN  amount
                   WHEN 'Expense'  THEN -amount
                   WHEN 'Transfer' THEN -amount END AS amt
  FROM mm_transactions
  WHERE date BETWEEN DATE '2025-01-01' AND DATE '2025-12-31'
    AND COALESCE(status, 'Active') <> 'Deleted'
  UNION ALL
  SELECT accountto AS acct, amount
  FROM mm_transactions
  WHERE date BETWEEN DATE '2025-01-01' AND DATE '2025-12-31'
    AND COALESCE(status, 'Active') <> 'Deleted'
    AND type = 'Transfer'
    AND COALESCE(accountto, '') <> ''
) x
WHERE acct IS NOT NULL AND acct <> ''
GROUP BY acct;

-- Pengaman: kalau ada nama akun 2025 yang tidak cocok dengan mm_accounts,
-- net-nya akan hilang diam-diam dan saldo jadi salah. Lebih baik batal.
-- Platform investasi (prefix "Invest:") memang bukan akun, jadi dikecualikan.
DO $$
DECLARE unmatched TEXT;
BEGIN
  SELECT string_agg(DISTINCT d.acct, ', ') INTO unmatched
  FROM _delta2025 d
  WHERE d.net <> 0
    AND d.acct NOT LIKE 'Invest:%'
    AND NOT EXISTS (
      SELECT 1 FROM mm_accounts a
      WHERE lower(trim(a.name)) = lower(trim(d.acct))
    );
  IF unmatched IS NOT NULL THEN
    RAISE EXCEPTION 'Nama akun di transaksi 2025 tidak ada di mm_accounts: %. Migrasi dibatalkan, tidak ada data yang berubah.', unmatched;
  END IF;
END $$;

UPDATE mm_accounts a
SET initialbalance = a.initialbalance + d.net
FROM _delta2025 d
WHERE lower(trim(a.name)) = lower(trim(d.acct));

-- ---------- 5. Buang detail 2025 ----------
DELETE FROM mm_transactions
WHERE date BETWEEN DATE '2025-01-01' AND DATE '2025-12-31';

COMMIT;
