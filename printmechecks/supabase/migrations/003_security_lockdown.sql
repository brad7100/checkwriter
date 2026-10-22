-- ============================================================
-- Security Lockdown - CRITICAL
-- Fixes legacy allow-all policies and anon role over-privileges
-- MUST RUN BEFORE 004_approval_workflow.sql
--
-- NOTE: Emergency lockdown (emergency_lockdown_remove_anon_access) 
-- already applied to production. This migration is idempotent 
-- and adds search_path fixes and additional hardening.
-- ============================================================

-- ====================
-- PART 1: DROP DANGEROUS LEGACY POLICIES
-- ====================

-- NOTE: In production, these were already dropped by emergency_lockdown_remove_anon_access
-- Using IF EXISTS makes this idempotent - safe to run on any environment

-- These policies allow anyone with the anon key to bypass all security
DROP POLICY IF EXISTS "Allow all operations on bank_accounts" ON public.bank_accounts;
DROP POLICY IF EXISTS "Allow all operations on checks" ON public.checks;
DROP POLICY IF EXISTS "Allow all operations on companies" ON public.companies;
DROP POLICY IF EXISTS "Allow all operations on custom_layouts" ON public.custom_layouts;

-- Drop any other overly permissive policies
DROP POLICY IF EXISTS "Enable all for authenticated users" ON public.bank_accounts;
DROP POLICY IF EXISTS "Enable all for authenticated users" ON public.checks;
DROP POLICY IF EXISTS "Enable all for authenticated users" ON public.companies;
DROP POLICY IF EXISTS "Enable all for authenticated users" ON public.custom_layouts;
DROP POLICY IF EXISTS "Enable all for authenticated users" ON public.profiles;
DROP POLICY IF EXISTS "Enable all for authenticated users" ON public.account_users;

-- ====================
-- PART 2: VERIFY PROPER POLICIES EXIST (FROM 001_users_and_permissions.sql)
-- ====================

-- These should already exist from migration 001, but we verify/recreate them
-- to ensure the app keeps working after dropping the allow-all policies

-- Companies: select if admin or has account access
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'companies' 
    AND policyname = 'Companies: select if admin or has account access'
  ) THEN
    CREATE POLICY "Companies: select if admin or has account access"
      ON public.companies FOR SELECT
      USING (
        public.is_admin()
        OR EXISTS (
          SELECT 1 FROM public.bank_accounts ba
          INNER JOIN public.account_users au ON au.bank_account_id = ba.id
          WHERE ba.company_id = companies.id AND au.user_id = auth.uid()
        )
      );
  END IF;
END $$;

-- Companies: insert/update/delete admin only
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'companies' 
    AND policyname = 'Companies: insert/update/delete admin only'
  ) THEN
    CREATE POLICY "Companies: insert/update/delete admin only"
      ON public.companies FOR ALL
      USING (public.is_admin())
      WITH CHECK (public.is_admin());
  END IF;
END $$;

-- Bank accounts: select if admin or allowed
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'bank_accounts' 
    AND policyname = 'Bank accounts: select if admin or allowed'
  ) THEN
    CREATE POLICY "Bank accounts: select if admin or allowed"
      ON public.bank_accounts FOR SELECT
      USING (
        public.is_admin()
        OR EXISTS (SELECT 1 FROM public.account_users WHERE user_id = auth.uid() AND bank_account_id = bank_accounts.id)
      );
  END IF;
END $$;

-- Bank accounts: insert/update/delete admin only
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'bank_accounts' 
    AND policyname = 'Bank accounts: insert/update/delete admin only'
  ) THEN
    CREATE POLICY "Bank accounts: insert/update/delete admin only"
      ON public.bank_accounts FOR ALL
      USING (public.is_admin())
      WITH CHECK (public.is_admin());
  END IF;
END $$;

-- Custom layouts: authenticated read (layouts are shared)
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'custom_layouts' 
    AND policyname = 'Custom layouts: authenticated read'
  ) THEN
    CREATE POLICY "Custom layouts: authenticated read"
      ON public.custom_layouts FOR SELECT
      TO authenticated
      USING (true);
  END IF;
END $$;

-- Custom layouts: admin write
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'custom_layouts' 
    AND policyname = 'Custom layouts: admin write'
  ) THEN
    CREATE POLICY "Custom layouts: admin write"
      ON public.custom_layouts FOR ALL
      USING (public.is_admin())
      WITH CHECK (public.is_admin());
  END IF;
END $$;

-- Checks: Basic policies (will be replaced by 004_approval_workflow.sql)
-- These ensure the app works between migrations 003 and 004
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'checks' 
    AND policyname = 'Checks: select if admin or account access'
  ) THEN
    CREATE POLICY "Checks: select if admin or account access"
      ON public.checks FOR SELECT
      USING (
        public.is_admin()
        OR EXISTS (SELECT 1 FROM public.account_users WHERE user_id = auth.uid() AND bank_account_id = checks.account_id)
      );
  END IF;
END $$;

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'checks' 
    AND policyname = 'Checks: insert if admin or account access'
  ) THEN
    CREATE POLICY "Checks: insert if admin or account access"
      ON public.checks FOR INSERT
      WITH CHECK (
        public.is_admin()
        OR EXISTS (SELECT 1 FROM public.account_users WHERE user_id = auth.uid() AND bank_account_id = checks.account_id)
      );
  END IF;
END $$;

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'checks' 
    AND policyname = 'Checks: update/delete if admin or account access'
  ) THEN
    CREATE POLICY "Checks: update/delete if admin or account access"
      ON public.checks FOR UPDATE
      USING (
        public.is_admin()
        OR EXISTS (SELECT 1 FROM public.account_users WHERE user_id = auth.uid() AND bank_account_id = checks.account_id)
      );
  END IF;
END $$;

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'checks' 
    AND policyname = 'Checks: delete if admin or account access'
  ) THEN
    CREATE POLICY "Checks: delete if admin or account access"
      ON public.checks FOR DELETE
      USING (
        public.is_admin()
        OR EXISTS (SELECT 1 FROM public.account_users WHERE user_id = auth.uid() AND bank_account_id = checks.account_id)
      );
  END IF;
END $$;

-- ====================
-- PART 3: REVOKE ANON PRIVILEGES
-- ====================

-- NOTE: In production, these were already revoked by emergency_lockdown_remove_anon_access
-- Safe to re-run - REVOKE is idempotent

-- Anon should have NO access to these tables
-- Only authenticated users should be able to do anything

REVOKE ALL ON public.companies FROM anon;
REVOKE ALL ON public.companies FROM public;

REVOKE ALL ON public.bank_accounts FROM anon;
REVOKE ALL ON public.bank_accounts FROM public;

REVOKE ALL ON public.checks FROM anon;
REVOKE ALL ON public.checks FROM public;

REVOKE ALL ON public.custom_layouts FROM anon;
REVOKE ALL ON public.custom_layouts FROM public;

REVOKE ALL ON public.profiles FROM anon;
REVOKE ALL ON public.profiles FROM public;

REVOKE ALL ON public.account_users FROM anon;
REVOKE ALL ON public.account_users FROM public;

-- Emergency lockdown also revoked TRUNCATE, TRIGGER, and REFERENCES from authenticated
-- We keep that restriction here for consistency
REVOKE TRUNCATE, TRIGGER, REFERENCES ON public.companies FROM authenticated;
REVOKE TRUNCATE, TRIGGER, REFERENCES ON public.bank_accounts FROM authenticated;
REVOKE TRUNCATE, TRIGGER, REFERENCES ON public.checks FROM authenticated;
REVOKE TRUNCATE, TRIGGER, REFERENCES ON public.custom_layouts FROM authenticated;
REVOKE TRUNCATE, TRIGGER, REFERENCES ON public.profiles FROM authenticated;
REVOKE TRUNCATE, TRIGGER, REFERENCES ON public.account_users FROM authenticated;

-- Grant only what authenticated users need (SELECT/INSERT/UPDATE/DELETE via RLS policies)
GRANT SELECT, INSERT, UPDATE, DELETE ON public.companies TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.bank_accounts TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.checks TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.custom_layouts TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.profiles TO authenticated;
GRANT SELECT, INSERT, DELETE ON public.account_users TO authenticated;

-- Sequences for authenticated users
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- ====================
-- PART 4: SECURE FUNCTIONS
-- ====================

-- NOTE: In production, emergency_lockdown_remove_anon_access already:
-- - Revoked EXECUTE on is_admin() and clear_must_set_password() from PUBLIC and anon
-- - Revoked EXECUTE on handle_new_user() from PUBLIC, anon, AND authenticated
-- - Did NOT set search_path (added here)

-- Revoke EXECUTE from anon/public on SECURITY DEFINER functions
-- Safe to re-run - REVOKE is idempotent
REVOKE EXECUTE ON FUNCTION public.is_admin() FROM anon;
REVOKE EXECUTE ON FUNCTION public.is_admin() FROM public;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM anon;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM public;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM authenticated;
-- handle_new_user is a trigger function, doesn't need explicit grant
-- Emergency lockdown revoked from authenticated too, we keep that

REVOKE EXECUTE ON FUNCTION public.update_updated_at_column() FROM anon;
REVOKE EXECUTE ON FUNCTION public.update_updated_at_column() FROM public;
-- update_updated_at_column is a trigger function, doesn't need explicit grant

-- NEW: Set secure search_path on SECURITY DEFINER functions
-- This was NOT done by emergency lockdown and is NEW protection
-- Prevents search_path injection attacks
ALTER FUNCTION public.is_admin() SET search_path = public, pg_temp;
ALTER FUNCTION public.handle_new_user() SET search_path = public, pg_temp;
ALTER FUNCTION public.update_updated_at_column() SET search_path = public, pg_temp;

-- If clear_must_set_password exists, secure it
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_proc 
    WHERE proname = 'clear_must_set_password' 
    AND pronamespace = 'public'::regnamespace
  ) THEN
    -- Emergency lockdown already revoked from PUBLIC and anon, keep authenticated
    EXECUTE 'REVOKE EXECUTE ON FUNCTION public.clear_must_set_password() FROM anon';
    EXECUTE 'REVOKE EXECUTE ON FUNCTION public.clear_must_set_password() FROM public';
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.clear_must_set_password() TO authenticated';
    -- NEW: Set search_path (not done by emergency lockdown)
    EXECUTE 'ALTER FUNCTION public.clear_must_set_password() SET search_path = public, pg_temp';
  END IF;
END $$;

-- ====================
-- PART 5: VERIFY RLS IS ENABLED
-- ====================

-- Ensure RLS is enabled on all tables
ALTER TABLE public.companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bank_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.custom_layouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.account_users ENABLE ROW LEVEL SECURITY;

-- Force RLS even for table owners (critical!)
ALTER TABLE public.companies FORCE ROW LEVEL SECURITY;
ALTER TABLE public.bank_accounts FORCE ROW LEVEL SECURITY;
ALTER TABLE public.checks FORCE ROW LEVEL SECURITY;
ALTER TABLE public.custom_layouts FORCE ROW LEVEL SECURITY;
ALTER TABLE public.profiles FORCE ROW LEVEL SECURITY;
ALTER TABLE public.account_users FORCE ROW LEVEL SECURITY;

-- ====================
-- PART 6: AUDIT CURRENT STATE
-- ====================

-- Create a view to monitor security posture
CREATE OR REPLACE VIEW public.security_audit AS
SELECT 
  'policy' as object_type,
  schemaname,
  tablename as object_name,
  policyname as detail,
  CASE 
    WHEN policyname LIKE '%all%' OR policyname LIKE '%Allow%' THEN 'WARNING: Potentially permissive'
    ELSE 'OK'
  END as status,
  roles,
  CASE WHEN cmd = 'ALL' THEN 'WARNING: ALL commands' ELSE cmd::text END as command,
  qual as using_clause,
  with_check as with_check_clause
FROM pg_policies
WHERE schemaname = 'public'
UNION ALL
SELECT
  'privilege' as object_type,
  'public' as schemaname,
  tablename as object_name,
  privilege_type as detail,
  CASE 
    WHEN grantee = 'anon' AND privilege_type != 'SELECT' THEN 'CRITICAL: anon has write access'
    WHEN grantee = 'anon' AND privilege_type = 'SELECT' THEN 'WARNING: anon has read access'
    WHEN grantee = 'public' THEN 'WARNING: public role has access'
    ELSE 'OK'
  END as status,
  ARRAY[grantee] as roles,
  privilege_type as command,
  NULL as using_clause,
  NULL as with_check_clause
FROM information_schema.table_privileges
WHERE table_schema = 'public'
  AND table_name IN ('companies', 'bank_accounts', 'checks', 'custom_layouts', 'profiles', 'account_users')
  AND grantee IN ('anon', 'public', 'authenticated')
UNION ALL
SELECT
  'function' as object_type,
  n.nspname as schemaname,
  p.proname as object_name,
  'SECURITY DEFINER' as detail,
  CASE 
    WHEN 'anon' = ANY(array_agg(r.rolname)) THEN 'CRITICAL: anon can execute'
    WHEN 'public' = ANY(array_agg(r.rolname)) THEN 'WARNING: public can execute'
    WHEN prosecdef AND NOT (prokind = 't' OR proname LIKE '%trigger%') THEN 'OK: SECURITY DEFINER'
    ELSE 'OK'
  END as status,
  array_agg(r.rolname) as roles,
  CASE WHEN prosecdef THEN 'SECURITY DEFINER' ELSE 'NORMAL' END as command,
  NULL as using_clause,
  NULL as with_check_clause
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
LEFT JOIN pg_proc_acl pa ON p.oid = pa.oid
LEFT JOIN pg_roles r ON pa.grantee = r.oid
WHERE n.nspname = 'public'
  AND prosecdef = true
GROUP BY n.nspname, p.proname, p.prosecdef, p.prokind
ORDER BY status DESC, object_type, object_name;

-- Grant authenticated users ability to check security posture
GRANT SELECT ON public.security_audit TO authenticated;

-- ====================
-- COMMENTS
-- ====================

COMMENT ON VIEW public.security_audit IS 'Security posture monitoring view - check for WARNING or CRITICAL items';

-- Log completion
DO $$
BEGIN
  RAISE NOTICE '=============================================================';
  RAISE NOTICE 'Security lockdown migration 003 completed';
  RAISE NOTICE '';
  RAISE NOTICE 'NOTE: Production already has emergency_lockdown_remove_anon_access applied';
  RAISE NOTICE 'This migration adds:';
  RAISE NOTICE '  - search_path fixes on SECURITY DEFINER functions (NEW)';
  RAISE NOTICE '  - TRUNCATE/TRIGGER/REFERENCES restrictions (confirmed)';
  RAISE NOTICE '  - Proper policies verification (idempotent)';
  RAISE NOTICE '  - Security audit view (NEW)';
  RAISE NOTICE '';
  RAISE NOTICE 'Verification:';
  RAISE NOTICE '  Run: SELECT * FROM security_audit WHERE status LIKE ''%%WARNING%%'' OR status LIKE ''%%CRITICAL%%'';';
  RAISE NOTICE '  Expected result: 0 rows (all critical issues resolved)';
  RAISE NOTICE '=============================================================';
END $$;
