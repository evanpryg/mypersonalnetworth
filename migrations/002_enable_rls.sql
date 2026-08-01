-- ============================================================
-- 002 — Kunci database: Row Level Security + login
-- ============================================================
-- JALANKAN PALING TERAKHIR, dan hanya setelah kamu berhasil login
-- lewat magic link di aplikasi. Sebelum skrip ini dijalankan,
-- database masih terbuka; sesudahnya, hanya sesi login-mu yang bisa baca/tulis.
--
-- Kenapa perlu: anon key ikut ter-bundle di halaman GitHub Pages yang publik.
-- Itu memang desain Supabase — anon key BUKAN rahasia. Yang seharusnya
-- melindungi data adalah RLS, dan sekarang RLS dimatikan di semua tabel,
-- sehingga siapa pun yang membuka source halaman bisa membaca dan menghapus
-- seluruh catatan keuanganmu.
--
-- URUTAN YANG BENAR:
--   1. Di Supabase → Authentication → URL Configuration, tambahkan
--      https://evanpryg.github.io/mypersonalnetworth/ ke "Redirect URLs"
--      dan set "Site URL" ke alamat yang sama.
--   2. Di Supabase → Authentication → Providers → Email, pastikan
--      "Email" aktif. Matikan "Enable Sign Ups" supaya orang lain tidak
--      bisa mendaftar sendiri.
--   3. Buka aplikasi, login lewat magic link, pastikan berhasil masuk.
--   4. Baru jalankan skrip ini.
--   5. Terakhir: ROTASI anon key (Project Settings → API). Key lama sudah
--      bocor di git history sejak commit cca3633.
-- ============================================================

BEGIN;

-- Ganti kalau alamat emailmu berbeda.
-- Policy mengunci akses ke SATU email, jadi walaupun ada orang lain yang
-- entah bagaimana punya akun di project ini, dia tetap tidak bisa melihat apa pun.
CREATE OR REPLACE FUNCTION is_owner() RETURNS BOOLEAN AS $$
  SELECT COALESCE(auth.jwt() ->> 'email', '') = 'pevan9111@gmail.com';
$$ LANGUAGE SQL STABLE;

DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'targets', 'transactions', 'portfolio', 'settings', 'allocation_targets',
    'mm_accounts', 'mm_transactions', 'mm_categories', 'mm_allocation', 'mm_summary'
  ] LOOP
    -- Lewati tabel yang belum ada (mm_summary kalau migrasi 001 belum jalan).
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables
                   WHERE table_schema = 'public' AND table_name = t) THEN
      RAISE NOTICE 'Tabel % tidak ada, dilewati.', t;
      CONTINUE;
    END IF;

    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS owner_all ON public.%I', t);
    EXECUTE format(
      'CREATE POLICY owner_all ON public.%I FOR ALL TO authenticated USING (is_owner()) WITH CHECK (is_owner())', t);

    -- Cabut hak akses anon sepenuhnya: tanpa login, tabel tidak terlihat.
    EXECUTE format('REVOKE ALL ON public.%I FROM anon', t);
  END LOOP;
END $$;

COMMIT;

-- ---------- Verifikasi ----------
-- Semua baris harus rowsecurity = true dan punya policy owner_all.
SELECT c.relname AS tabel,
       c.relrowsecurity AS rls_aktif,
       COALESCE(p.policyname, '(tidak ada policy)') AS policy
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
LEFT JOIN pg_policies p ON p.tablename = c.relname AND p.schemaname = 'public'
WHERE n.nspname = 'public'
  AND c.relkind = 'r'
  AND c.relname IN ('targets','transactions','portfolio','settings','allocation_targets',
                    'mm_accounts','mm_transactions','mm_categories','mm_allocation','mm_summary')
ORDER BY c.relname;
