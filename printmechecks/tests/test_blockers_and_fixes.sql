-- Test script for blockers and fixes in 005_approval_workflow.sql
-- This test starts from a schema matching production BEFORE 005 is applied:
-- - NO status column on checks table
-- - 454 checks with is_printed=true
-- - 28 checks with is_printed=false
-- - Production uses PostgreSQL 17.6
--
-- Then applies migrations 004, 005, 006 and verifies all five fixes:
-- 1. Status backfill correctly sets 454 printed and 28 approved
-- 2. Submitter BEFORE INSERT coercion blocks is_printed=true
-- 3. approval_queue view respects RLS (security_invoker)
-- 4. log_check_audit cannot be called by authenticated users
-- 5. bulk_approve_checks requires account access

\set ON_ERROR_STOP on

-- Drop and recreate test database
DROP DATABASE IF EXISTS test_approval_workflow;
CREATE DATABASE test_approval_workflow;
\c test_approval_workflow

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

-- Create base schema matching production BEFORE status column
-- This matches migrations 20251005000000_initial_schema.sql + 001 + 002

CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'submitter' CHECK (role IN ('submitter', 'approver', 'admin')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.bank_accounts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
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
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed test users matching production
INSERT INTO auth.users (id, email) VALUES
  ('11111111-1111-1111-1111-111111111111', 'brad@bradwilliamslaw.com'),
  ('22222222-2222-2222-2222-222222222222', 'karen@bradwilliamslaw.com'),
  ('33333333-3333-3333-3333-333333333333', 'frederick@example.com'),
  ('44444444-4444-4444-4444-444444444444', 'bot@example.com');

INSERT INTO public.profiles (id, email, role) VALUES
  ('11111111-1111-1111-1111-111111111111', 'brad@bradwilliamslaw.com', 'admin'),
  ('22222222-2222-2222-2222-222222222222', 'karen@bradwilliamslaw.com', 'approver'),
  ('33333333-3333-3333-3333-333333333333', 'frederick@example.com', 'submitter'),
  ('44444444-4444-4444-4444-444444444444', 'bot@example.com', 'submitter');

-- Create test bank accounts
INSERT INTO public.bank_accounts (id, account_name, account_number, routing_number) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Operating Account', '12347857', '111000025'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Trust Account', '12340992', '111000025');

-- Grant Karen access to both accounts
INSERT INTO public.account_users (bank_account_id, user_id) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '22222222-2222-2222-2222-222222222222'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '22222222-2222-2222-2222-222222222222');

-- Grant Frederick access only to Operating Account
INSERT INTO public.account_users (bank_account_id, user_id) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '33333333-3333-3333-3333-333333333333');

-- Seed 454 printed checks and 28 unprinted checks (matching production counts)
-- Note: NO status column exists yet!
DO $$
DECLARE
  i INT;
BEGIN
  -- 454 printed checks
  FOR i IN 1..454 LOOP
    INSERT INTO public.checks (
      account_id,
      check_number,
      pay_to,
      amount,
      memo,
      check_date,
      is_printed,
      printed_date
    ) VALUES (
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'P-' || i,
      'Vendor ' || i,
      100.00 + (i % 100),
      'Invoice ' || i,
      '2024-01-01'::DATE + (i || ' days')::INTERVAL,
      true,
      '2024-01-01'::TIMESTAMPTZ + (i || ' days')::INTERVAL
    );
  END LOOP;
  
  -- 28 unprinted checks
  FOR i IN 1..28 LOOP
    INSERT INTO public.checks (
      account_id,
      check_number,
      pay_to,
      amount,
      memo,
      check_date,
      is_printed,
      printed_date
    ) VALUES (
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'U-' || i,
      'Pending Vendor ' || i,
      50.00 + (i % 50),
      'Pending ' || i,
      CURRENT_DATE,
      false,
      NULL
    );
  END LOOP;
END $$;

-- Verify pre-migration state
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
\echo '=== APPLYING MIGRATION 004 (security lockdown) ==='
\i /workspace/printmechecks/supabase/migrations/004_security_lockdown.sql

\echo ''
\echo '=== APPLYING MIGRATION 005 (approval workflow) ==='
\i /workspace/printmechecks/supabase/migrations/005_approval_workflow.sql

\echo ''
\echo '=== APPLYING MIGRATION 006 (bot submission) ==='
\i /workspace/printmechecks/supabase/migrations/006_bot_submission.sql

\echo ''
\echo '==========================='
\echo '=== TEST 1: BLOCKER 1 - Status backfill correctness ==='
\echo '==========================='

-- Verify exactly 454 printed and 28 approved
SELECT 
  COUNT(*) FILTER (WHERE status = 'printed') as printed_count_actual,
  COUNT(*) FILTER (WHERE status = 'approved') as approved_count_actual,
  COUNT(*) as total_count,
  CASE 
    WHEN COUNT(*) FILTER (WHERE status = 'printed') = 454 
     AND COUNT(*) FILTER (WHERE status = 'approved') = 28
    THEN 'PASS'
    ELSE 'FAIL'
  END as test_result
FROM public.checks;

\echo ''
\echo '==========================='
\echo '=== TEST 2: BLOCKER 2 - Submitter INSERT coercion ==='
\echo '==========================='

-- Test 2a: Submitter inserting with is_printed=true should be coerced to pending, is_printed=false
SET request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333'; -- Frederick (submitter)

INSERT INTO public.checks (
  account_id,
  check_number,
  pay_to,
  amount,
  memo,
  check_date,
  is_printed,
  printed_date,
  status
) VALUES (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'TEST-SUB-1',
  'Test Payee',
  100.00,
  'Submitter trying to print',
  CURRENT_DATE,
  true,  -- Submitter tries to set this to true
  NOW(), -- and set printed_date
  'printed' -- and status to printed
) RETURNING id, status, is_printed, printed_date IS NOT NULL as has_printed_date;

-- Verify the inserted check was coerced
SELECT 
  status = 'pending' as status_is_pending,
  is_printed = false as is_printed_is_false,
  printed_date IS NULL as printed_date_is_null,
  CASE 
    WHEN status = 'pending' AND is_printed = false AND printed_date IS NULL 
    THEN 'PASS'
    ELSE 'FAIL'
  END as test_2a_result
FROM public.checks
WHERE check_number = 'TEST-SUB-1';

-- Test 2b: Approver inserting with is_printed=true should get status='printed'
RESET request.jwt.claim.sub;
SET request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222'; -- Karen (approver)

INSERT INTO public.checks (
  account_id,
  check_number,
  pay_to,
  amount,
  memo,
  check_date,
  is_printed,
  printed_date,
  status
) VALUES (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'TEST-APP-1',
  'Test Payee 2',
  200.00,
  'Approver printing',
  CURRENT_DATE,
  true,  -- Approver sets this
  NOW(),
  'approved' -- This should be overridden to 'printed'
) RETURNING id, status, is_printed;

-- Verify approver's check
SELECT 
  status = 'printed' as status_is_printed,
  is_printed = true as is_printed_is_true,
  CASE 
    WHEN status = 'printed' AND is_printed = true 
    THEN 'PASS'
    ELSE 'FAIL'
  END as test_2b_result
FROM public.checks
WHERE check_number = 'TEST-APP-1';

\echo ''
\echo '==========================='
\echo '=== TEST 3: approval_queue view security_invoker ==='
\echo '==========================='

-- Verify the view was created WITH (security_invoker = true)
SELECT 
  CASE 
    WHEN EXISTS (
      SELECT 1 
      FROM pg_views 
      WHERE viewname = 'approval_queue' 
      AND schemaname = 'public'
    ) THEN 'View exists'
    ELSE 'FAIL: View does not exist'
  END as view_exists;

-- Note: We can't fully test RLS enforcement without actual RLS policies active,
-- but we can verify the view option is set
SELECT 
  reloptions::text,
  CASE 
    WHEN reloptions::text LIKE '%security_invoker=true%' 
    THEN 'PASS: security_invoker=true is set'
    ELSE 'FAIL: security_invoker=true NOT set'
  END as test_3_result
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relname = 'approval_queue' 
  AND n.nspname = 'public'
  AND c.relkind = 'v';

\echo ''
\echo '==========================='
\echo '=== TEST 4: log_check_audit revocation ==='
\echo '==========================='

-- Test 4: Authenticated user should NOT be able to call log_check_audit
SET request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222'; -- Karen (approver)

-- This should FAIL with permission denied
DO $$
DECLARE
  test_check_id UUID;
BEGIN
  -- Get a check ID for testing
  SELECT id INTO test_check_id FROM public.checks LIMIT 1;
  
  -- Try to call log_check_audit directly (should fail)
  BEGIN
    PERFORM public.log_check_audit(
      test_check_id,
      'test_action',
      NULL,
      NULL
    );
    RAISE EXCEPTION 'FAIL: log_check_audit was callable by authenticated user!';
  EXCEPTION
    WHEN insufficient_privilege THEN
      RAISE NOTICE 'PASS: log_check_audit correctly blocked for authenticated users';
  END;
END $$;

\echo ''
\echo '==========================='
\echo '=== TEST 5: bulk_approve_checks account access ==='
\echo '==========================='

-- Set up test: Create a pending check on Trust Account (Frederick has NO access to it)
RESET request.jwt.claim.sub;
SET request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222'; -- Karen (has access)

INSERT INTO public.checks (
  account_id,
  check_number,
  pay_to,
  amount,
  memo,
  check_date,
  status,
  created_by
) VALUES (
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', -- Trust Account
  'TEST-BULK-1',
  'Test Bulk Approve',
  300.00,
  'For bulk test',
  CURRENT_DATE,
  'pending',
  '44444444-4444-4444-4444-444444444444' -- Bot created it
) RETURNING id;

-- Get the check ID
DO $$
DECLARE
  test_check_id UUID;
  bulk_result RECORD;
BEGIN
  SELECT id INTO test_check_id FROM public.checks WHERE check_number = 'TEST-BULK-1';
  
  -- Test 5a: Karen (approver with access) should be able to bulk approve
  PERFORM set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
  
  FOR bulk_result IN 
    SELECT * FROM public.bulk_approve_checks(ARRAY[test_check_id])
  LOOP
    IF bulk_result.success THEN
      RAISE NOTICE 'PASS 5a: Karen can bulk approve checks on her accounts';
    ELSE
      RAISE EXCEPTION 'FAIL 5a: Karen could not approve: %', bulk_result.error;
    END IF;
  END LOOP;
  
  -- Reset check to pending for next test
  UPDATE public.checks SET status = 'pending', approved_by = NULL, approved_at = NULL
  WHERE id = test_check_id;
  
  -- Test 5b: Frederick (submitter WITHOUT access to Trust Account) should NOT be able to bulk approve
  PERFORM set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', true);
  
  FOR bulk_result IN 
    SELECT * FROM public.bulk_approve_checks(ARRAY[test_check_id])
  LOOP
    IF NOT bulk_result.success AND bulk_result.error LIKE '%no access%' THEN
      RAISE NOTICE 'PASS 5b: Frederick blocked from approving check on unauthorized account';
    ELSE
      RAISE EXCEPTION 'FAIL 5b: Frederick was able to approve unauthorized check!';
    END IF;
  END LOOP;
END $$;

\echo ''
\echo '==========================='
\echo '=== ALL TESTS SUMMARY ==='
\echo '==========================='
\echo 'If you see PASS for all tests above, all 5 fixes are working correctly!'
\echo ''
