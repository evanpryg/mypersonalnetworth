-- ============================================================
-- 003 — Disable RLS: single-user mode, no login required
-- ============================================================
-- Run this in Supabase → SQL Editor to undo migration 002.
-- After running this, the app will work without any login.
--
-- WARNING: anyone who has your Supabase URL and anon key can
-- read and write all your data. This is acceptable only if
-- you are the sole user and keep the credentials private.
-- ============================================================

BEGIN;

-- Drop the owner-only policies and disable RLS on every table.
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

    -- Restore anon access so the app works without a session token.
    EXECUTE format('GRANT ALL ON public.%I TO anon', t);
  END LOOP;
END $$;

-- Drop the helper function created by 002.
DROP FUNCTION IF EXISTS is_owner();

COMMIT;

-- ---------- Verification ----------
-- All rows should show relrowsecurity = false.
SELECT c.relname AS table_name,
       c.relrowsecurity AS rls_enabled
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind = 'r'
  AND c.relname IN ('targets','transactions','portfolio','settings','allocation_targets',
                    'mm_accounts','mm_transactions','mm_categories','mm_allocation','mm_summary')
ORDER BY c.relname;
