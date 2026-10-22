-- Focused test for 005_approval_workflow.sql fixes
-- Tests all 5 fixes (2 blockers + 3 should-fix items)
-- Starts from production schema state: NO status column

\set ON_ERROR_STOP on

-- Drop and recreate test database
DROP DATABASE IF EXISTS test_005_fixes;
CREATE DATABASE test_005_fixes;
\c test_005_fixes

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE SCHEMA IF NOT EXISTS extensions;
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

-- Create auth schema (simulating Supabase auth)
CREATE SCHEMA IF NOT EXISTS auth;
CREATE TABLE IF NOT EXISTS auth.users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email TEXT UNIQUE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Mock auth.uid() function
CREATE OR REPLACE FUNCTION auth.uid()
RETURNS UUID AS $$
  SELECT NULLIF(current_setting('request.jwt.claim.sub', true), '')::UUID;
$$ LANGUAGE SQL STABLE;

-- Create Supabase roles
DO $$
BEGIN
  CREATE ROLE anon NOLOGIN NOINHERIT;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$
BEGIN
  CREATE ROLE authenticated NOLOGIN NOINHERIT;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$
BEGIN
  CREATE ROLE service_role NOLOGIN NOINHERIT;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
GRANT anon TO postgres;
GRANT authenticated TO postgres;
GRANT service_role TO postgres;

-- Create base schema matching production BEFORE 005
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'submitter' CHECK (role IN ('submitter', 'approver', 'admin')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.companies (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.bank_accounts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id UUID REFERENCES public.companies(id),
  account_name TEXT NOT NULL,
  account_number TEXT NOT NULL,
  routing_number TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.account_users (
  bank_account_id UUID NOT NULL REFERENCES public.bank_accounts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (bank_account_id, user_id)
);

-- Create is_admin() function required by 005
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
$$ LANGUAGE SQL STABLE SECURITY DEFINER SET search_path = public, pg_temp;

-- Create can_approve_checks() function required by 005
CREATE OR REPLACE FUNCTION public.can_approve_checks()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role IN ('approver', 'admin')
  );
$$ LANGUAGE SQL STABLE SECURITY DEFINER SET search_path = public, pg_temp;

-- checks table WITHOUT status column (production state before 005)
CREATE TABLE IF NOT EXISTS public.checks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  account_id UUID NOT NULL REFERENCES public.bank_accounts(id),
  check_number TEXT,
  pay_to TEXT NOT NULL,
  amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
  memo TEXT,
  check_date DATE NOT NULL,
  is_printed BOOLEAN DEFAULT false,
  printed_date TIMESTAMPTZ,
  is_legacy BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed test users
INSERT INTO auth.users (id, email) VALUES
  ('11111111-1111-1111-1111-111111111111', 'brad@bradwilliamslaw.com'),
  ('22222222-2222-2222-2222-222222222222', 'karen@bradwilliamslaw.com'),
  ('33333333-3333-3333-3333-333333333333', 'frederick@example.com'),
  ('44444444-4444-4444-4444-444444444444', 'bot@example.com'),
  ('55555555-5555-5555-5555-555555555555', 'alice@example.com');

INSERT INTO public.profiles (id, email, role) VALUES
  ('11111111-1111-1111-1111-111111111111', 'brad@bradwilliamslaw.com', 'admin'),
  ('22222222-2222-2222-2222-222222222222', 'karen@bradwilliamslaw.com', 'approver'),
  ('33333333-3333-3333-3333-333333333333', 'frederick@example.com', 'submitter'),
  ('44444444-4444-4444-4444-444444444444', 'bot@example.com', 'submitter'),
  ('55555555-5555-5555-5555-555555555555', 'alice@example.com', 'approver');

-- Create test company
INSERT INTO public.companies (id, name) VALUES
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'Brad Williams Law');

-- Create test bank accounts
INSERT INTO public.bank_accounts (id, company_id, account_name, account_number, routing_number) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'Operating Account', '12347857', '111000025'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'Trust Account', '12340992', '111000025');

-- Grant Karen access to both accounts
INSERT INTO public.account_users (bank_account_id, user_id) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '22222222-2222-2222-2222-222222222222'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '22222222-2222-2222-2222-222222222222');

-- Grant Frederick access only to Operating Account
INSERT INTO public.account_users (bank_account_id, user_id) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '33333333-3333-3333-3333-333333333333');

-- Grant Alice (approver) access only to Operating Account (NOT Trust Account)
INSERT INTO public.account_users (bank_account_id, user_id) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '55555555-5555-5555-5555-555555555555');

-- Seed 454 printed checks and 28 unprinted checks (matching production)
DO $$
DECLARE
  i INT;
BEGIN
  -- 454 printed checks
  FOR i IN 1..454 LOOP
    INSERT INTO public.checks (
      account_id, check_number, pay_to, amount, memo, check_date,
      is_printed, printed_date, is_legacy
    ) VALUES (
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'P-' || i, 'Vendor ' || i, 100.00 + (i % 100), 'Invoice ' || i,
      '2024-01-01'::DATE + (i || ' days')::INTERVAL,
      true, '2024-01-01'::TIMESTAMPTZ + (i || ' days')::INTERVAL, true
    );
  END LOOP;
  
  -- 28 unprinted checks
  FOR i IN 1..28 LOOP
    INSERT INTO public.checks (
      account_id, check_number, pay_to, amount, memo, check_date,
      is_printed, printed_date, is_legacy
    ) VALUES (
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'U-' || i, 'Pending Vendor ' || i, 50.00 + (i % 50), 'Pending ' || i,
      CURRENT_DATE, false, NULL, true
    );
  END LOOP;
END $$;

\echo ''
\echo '=== PRE-MIGRATION STATE ==='
SELECT 
  COUNT(*) FILTER (WHERE is_printed = true) as printed_count,
  COUNT(*) FILTER (WHERE is_printed = false) as unprinted_count,
  COUNT(*) as total_count
FROM public.checks;

-- Confirm status column does NOT exist
SELECT 
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'checks' AND column_name = 'status'
    ) THEN 'FAIL: status column already exists!'
    ELSE 'PASS: No status column (production state)'
  END as pre_migration_check;

\echo ''
\echo '=== APPLYING MIGRATION 005 ==='
\i /migrations/005_approval_workflow.sql

\echo ''
\echo '============================='
\echo '=== TEST 1: BLOCKER 1 - Status backfill correctness ==='
\echo '============================='

SELECT 
  COUNT(*) FILTER (WHERE status = 'printed') as printed_count_actual,
  COUNT(*) FILTER (WHERE status = 'approved') as approved_count_actual,
  COUNT(*) as total_count,
  CASE 
    WHEN COUNT(*) FILTER (WHERE status = 'printed') = 454 
     AND COUNT(*) FILTER (WHERE status = 'approved') = 28
    THEN '✅ PASS'
    ELSE '❌ FAIL'
  END as test_result
FROM public.checks;

\echo ''
\echo '============================='
\echo '=== TEST 2: BLOCKER 2 - Submitter INSERT coercion ==='
\echo '============================='

-- Test 2a: Submitter inserting with is_printed=true
SET request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333'; -- Frederick (submitter)

INSERT INTO public.checks (
  account_id, check_number, pay_to, amount, memo, check_date,
  is_printed, printed_date, status
) VALUES (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'TEST-SUB-1',
  'Test Payee', 100.00, 'Submitter trying to print', CURRENT_DATE,
  true, NOW(), 'printed'
);

SELECT 
  check_number,
  status,
  is_printed,
  printed_date IS NOT NULL as has_printed_date,
  CASE 
    WHEN status = 'pending' AND is_printed = false AND printed_date IS NULL 
    THEN '✅ PASS'
    ELSE '❌ FAIL'
  END as test_2a_result
FROM public.checks
WHERE check_number = 'TEST-SUB-1';

-- Test 2b: Approver inserting with is_printed=true
RESET request.jwt.claim.sub;
SET request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222'; -- Karen (approver)

INSERT INTO public.checks (
  account_id, check_number, pay_to, amount, memo, check_date,
  is_printed, printed_date, status
) VALUES (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'TEST-APP-1',
  'Test Payee 2', 200.00, 'Approver printing', CURRENT_DATE,
  true, NOW(), 'approved'
);

SELECT 
  check_number,
  status,
  is_printed,
  CASE 
    WHEN status = 'printed' AND is_printed = true 
    THEN '✅ PASS'
    ELSE '❌ FAIL'
  END as test_2b_result
FROM public.checks
WHERE check_number = 'TEST-APP-1';

\echo ''
\echo '============================='
\echo '=== TEST 3: approval_queue view security_invoker ==='
\echo '============================='

SELECT 
  c.relname as view_name,
  COALESCE(c.reloptions::text, 'no options') as options,
  CASE 
    WHEN c.reloptions::text LIKE '%security_invoker=true%' 
    THEN '✅ PASS: security_invoker=true is set'
    ELSE '❌ FAIL: security_invoker=true NOT set'
  END as test_3_result
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relname = 'approval_queue' 
  AND n.nspname = 'public'
  AND c.relkind = 'v';

\echo ''
\echo '============================='
\echo '=== TEST 4: log_check_audit revocation ==='
\echo '============================='

-- Verify execute permission was revoked from authenticated role
SELECT 
  p.proname as function_name,
  CASE 
    WHEN has_function_privilege('authenticated', p.oid, 'EXECUTE') 
    THEN '❌ FAIL: authenticated can still execute'
    ELSE '✅ PASS: authenticated cannot execute'
  END as test_4_result
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' 
  AND p.proname = 'log_check_audit';

\echo ''
\echo '============================='
\echo '=== TEST 5: bulk_approve_checks account access ==='
\echo '============================='

-- Create two pending checks on Trust Account
SET request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222'; -- Karen

INSERT INTO public.checks (
  account_id, check_number, pay_to, amount, memo, check_date,
  status, created_by
) VALUES (
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'TEST-BULK-KAREN',
  'Test Bulk Approve Karen', 300.00, 'For Karen test', CURRENT_DATE,
  'pending', '44444444-4444-4444-4444-444444444444'
);

INSERT INTO public.checks (
  account_id, check_number, pay_to, amount, memo, check_date,
  status, created_by
) VALUES (
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'TEST-BULK-ALICE',
  'Test Bulk Approve Alice', 400.00, 'For Alice test', CURRENT_DATE,
  'pending', '44444444-4444-4444-4444-444444444444'
);

DO $$
DECLARE
  karen_check_id UUID;
  alice_check_id UUID;
  bulk_result RECORD;
  test_5a_passed BOOLEAN := false;
  test_5b_passed BOOLEAN := false;
BEGIN
  SELECT id INTO karen_check_id FROM public.checks WHERE check_number = 'TEST-BULK-KAREN';
  SELECT id INTO alice_check_id FROM public.checks WHERE check_number = 'TEST-BULK-ALICE';
  
  -- Test 5a: Karen (approver with access to Trust Account) can approve
  PERFORM set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
  
  FOR bulk_result IN 
    SELECT * FROM public.bulk_approve_checks(ARRAY[karen_check_id])
  LOOP
    IF bulk_result.success THEN
      RAISE NOTICE '✅ PASS 5a: Karen can bulk approve checks on her accounts';
      test_5a_passed := true;
    ELSE
      RAISE EXCEPTION '❌ FAIL 5a: Karen could not approve: %', bulk_result.error;
    END IF;
  END LOOP;
  
  -- Test 5b: Alice (approver but NO access to Trust Account) cannot approve
  PERFORM set_config('request.jwt.claim.sub', '55555555-5555-5555-5555-555555555555', true);
  
  FOR bulk_result IN 
    SELECT * FROM public.bulk_approve_checks(ARRAY[alice_check_id])
  LOOP
    IF NOT bulk_result.success AND bulk_result.error LIKE '%no access%' THEN
      RAISE NOTICE '✅ PASS 5b: Alice (approver without account access) blocked';
      test_5b_passed := true;
    ELSE
      RAISE EXCEPTION '❌ FAIL 5b: Alice was able to approve unauthorized check! (success=%, error=%)', 
        bulk_result.success, bulk_result.error;
    END IF;
  END LOOP;
  
  IF NOT (test_5a_passed AND test_5b_passed) THEN
    RAISE EXCEPTION 'Test 5 failed';
  END IF;
END $$;

\echo ''
\echo '============================='
\echo '=== ALL TESTS SUMMARY ==='
\echo '============================='
\echo 'If all tests show ✅ PASS, all 5 fixes are working correctly!'
\echo ''
