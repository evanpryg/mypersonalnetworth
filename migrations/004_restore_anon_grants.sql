-- ============================================================
-- 004 — Restore anon access (fix "permission denied for table")
-- ============================================================
-- Symptom: the app loads empty and the console shows
--   code 42501, "permission denied for table mm_accounts"
--   hint: GRANT SELECT ON public.mm_accounts TO anon;
-- on every table (HTTP 401). RLS is not the cause — the anon role has
-- simply lost its table privileges (migration 002 revoked them, or the
-- project's default grants no longer cover the public schema).
--
-- This restores what single-user mode needs: schema usage, full table
-- access, sequence access for inserts, and the same grants for tables
-- created later. Safe to run more than once.
--
-- WARNING: as with 003, anyone holding the URL + anon key (it ships in
-- the page) can read and write all data. Fine only for a private,
-- single-user app. To lock it down again, run 002.
-- ============================================================

BEGIN;

GRANT USAGE ON SCHEMA public TO anon, authenticated;

DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'targets', 'transactions', 'portfolio', 'settings', 'allocation_targets',
    'mm_accounts', 'mm_transactions', 'mm_categories', 'mm_allocation', 'mm_summary'
  ] LOOP
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables
                   WHERE table_schema = 'public' AND table_name = t) THEN
      RAISE NOTICE 'Table % does not exist, skipped.', t;
      CONTINUE;
    END IF;

    EXECUTE format('DROP POLICY IF EXISTS owner_all ON public.%I', t);
    EXECUTE format('ALTER TABLE public.%I DISABLE ROW LEVEL SECURITY', t);
    EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON public.%I TO anon, authenticated', t);
  END LOOP;
END $$;

-- Identity/serial columns need their sequences for INSERT to work.
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;

-- Tables and sequences created later get the same access.
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO anon, authenticated;

COMMIT;

-- ---------- Verification ----------
-- Every row should show anon_can_select = true and rls_enabled = false.
SELECT c.relname AS table_name,
       has_table_privilege('anon', c.oid, 'SELECT') AS anon_can_select,
       c.relrowsecurity AS rls_enabled
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind = 'r'
  AND c.relname IN ('targets','transactions','portfolio','settings','allocation_targets',
                    'mm_accounts','mm_transactions','mm_categories','mm_allocation','mm_summary')
ORDER BY c.relname;
