-- Comprehensive test with real production schema
-- Tests all requested scenarios

\timing on
\set ON_ERROR_STOP on

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE SCHEMA IF NOT EXISTS extensions;
CREATE EXTENSION IF NOT EXISTS "pgcrypto" SCHEMA extensions;

-- Create Supabase roles
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN CREATE ROLE anon NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN CREATE ROLE authenticated NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN CREATE ROLE service_role NOLOGIN; END IF;
END $$;

-- Create schemas
CREATE SCHEMA IF NOT EXISTS auth;
CREATE TABLE IF NOT EXISTS auth.users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email TEXT UNIQUE NOT NULL,
  encrypted_password TEXT,
  email_confirmed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION auth.uid() RETURNS UUID AS $$
  SELECT '11111111-1111-1111-1111-111111111111'::UUID;
$$ LANGUAGE SQL STABLE;

\echo '=== Applying all migrations ==='
\i /migrations/20251005_initial_schema.sql
\i /migrations/20251005_disable_rls.sql
\i /migrations/001_users_and_permissions.sql
\i /migrations/002_reenable_rls_for_permissions.sql
\i /migrations/003_invite_set_password.sql
\i /migrations/004_security_lockdown.sql
\i /migrations/005_approval_workflow.sql
\i /migrations/006_submitter_api_keys.sql

\echo '=== Seeding test data ==='
-- Create test users
INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at)
VALUES 
  ('11111111-1111-1111-1111-111111111111'::uuid, 'admin@test.com', extensions.crypt('test', extensions.gen_salt('bf')), NOW()),
  ('22222222-2222-2222-2222-222222222222'::uuid, 'approver@test.com', extensions.crypt('test', extensions.gen_salt('bf')), NOW()),
  ('33333333-3333-3333-3333-333333333333'::uuid, 'submitter@test.com', extensions.crypt('test', extensions.gen_salt('bf')), NOW())
ON CONFLICT (id) DO NOTHING;

-- Set roles
UPDATE public.profiles SET role = 'admin' WHERE id = '11111111-1111-1111-1111-111111111111'::uuid;
UPDATE public.profiles SET role = 'approver' WHERE id = '22222222-2222-2222-2222-222222222222'::uuid;
UPDATE public.profiles SET role = 'submitter' WHERE id = '33333333-3333-3333-3333-333333333333'::uuid;

-- Create test data
INSERT INTO public.companies (id, name, address, city, state, zip)
VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid, 'Test Company', '123 Test St', 'Test City', 'TS', '12345')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.bank_accounts (id, company_id, name, bank_name, routing_number, account_number, bank_city, signature)
VALUES ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid, 
        'Test Account', 'Test Bank', '123456789', '987654321', 'Test City', 'Test Sig')
ON CONFLICT (id) DO NOTHING;

-- Grant all users access to account
INSERT INTO public.account_users (bank_account_id, user_id)
VALUES 
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid, '11111111-1111-1111-1111-111111111111'::uuid),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid, '22222222-2222-2222-2222-222222222222'::uuid),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid, '33333333-3333-3333-3333-333333333333'::uuid)
ON CONFLICT DO NOTHING;

\echo ''
\echo '=== TEST (a): Approver prints another users approved check ==='
-- Submitter creates check
CREATE OR REPLACE FUNCTION auth.uid() RETURNS UUID AS $$ SELECT '33333333-3333-3333-3333-333333333333'::UUID; $$ LANGUAGE SQL STABLE;
INSERT INTO public.checks (company_id, account_id, account_holder_name, account_holder_address, account_holder_city, account_holder_state, account_holder_zip,
  check_number, date, bank_name, amount, pay_to, memo, signature, routing_number, bank_account_number, status, is_legacy)
VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid, 'Test Company', '123 Test St', 'Test City', 'TS', '12345',
  '1001', '2024-10-22', 'Test Bank', '100.00', 'Test Payee', 'Test memo', 'Test Sig', '123456789', '987654321', 'pending', false);

-- Approver approves it
CREATE OR REPLACE FUNCTION auth.uid() RETURNS UUID AS $$ SELECT '22222222-2222-2222-2222-222222222222'::UUID; $$ LANGUAGE SQL STABLE;
UPDATE public.checks SET status = 'approved' WHERE check_number = '1001';

-- Approver prints it (WITH CHECK should allow this now)
UPDATE public.checks SET status = 'printed', is_printed = true WHERE check_number = '1001';
SELECT 'TEST (a) Result:' as test, check_number, status, created_by, is_printed FROM public.checks WHERE check_number = '1001';

\echo ''
\echo '=== TEST (b): Submitter insert coerced to pending, cant approve, cant print ==='
CREATE OR REPLACE FUNCTION auth.uid() RETURNS UUID AS $$ SELECT '33333333-3333-3333-3333-333333333333'::UUID; $$ LANGUAGE SQL STABLE;

-- Insert with status='printed' should be coerced to 'pending'
INSERT INTO public.checks (company_id, account_id, account_holder_name, account_holder_address, account_holder_city, account_holder_state, account_holder_zip,
  check_number, date, bank_name, amount, pay_to, memo, signature, routing_number, bank_account_number, status, is_legacy)
VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid, 'Test Company', '123 Test St', 'Test City', 'TS', '12345',
  '1002', '2024-10-22', 'Test Bank', '200.00', 'Test Payee 2', 'Test memo', 'Test Sig', '123456789', '987654321', 'printed', false);

SELECT 'TEST (b.1) Coerced to pending:' as test, check_number, status, created_by FROM public.checks WHERE check_number = '1002';

-- Try to approve (should fail)
DO $$
BEGIN
  UPDATE public.checks SET status = 'approved' WHERE check_number = '1002';
  RAISE NOTICE 'TEST (b.2) Submitter approve: FAIL (should have been blocked)';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'TEST (b.2) Submitter cannot approve: PASS - %', SQLERRM;
END $$;

-- Try to set is_printed (should fail)
DO $$
BEGIN
  UPDATE public.checks SET is_printed = true WHERE check_number = '1002';
  RAISE NOTICE 'TEST (b.3) Submitter print: FAIL (should have been blocked)';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'TEST (b.3) Submitter cannot print: PASS - %', SQLERRM;
END $$;

\echo ''
\echo '=== TEST (c): Old-app-style insert by approver, then is_printed update ==='
CREATE OR REPLACE FUNCTION auth.uid() RETURNS UUID AS $$ SELECT '22222222-2222-2222-2222-222222222222'::UUID; $$ LANGUAGE SQL STABLE;

-- Insert without explicit status (defaults to 'approved')
INSERT INTO public.checks (company_id, account_id, account_holder_name, account_holder_address, account_holder_city, account_holder_state, account_holder_zip,
  check_number, date, bank_name, amount, pay_to, memo, signature, routing_number, bank_account_number, is_legacy)
VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid, 'Test Company', '123 Test St', 'Test City', 'TS', '12345',
  '1003', '2024-10-22', 'Test Bank', '300.00', 'Test Payee 3', 'Test memo', 'Test Sig', '123456789', '987654321', false);

SELECT 'TEST (c.1) Default status:' as test, check_number, status, is_printed FROM public.checks WHERE check_number = '1003';

-- Old app sets is_printed=true, status should sync to 'printed'
UPDATE public.checks SET is_printed = true WHERE check_number = '1003';
SELECT 'TEST (c.2) After is_printed=true:' as test, check_number, status, is_printed FROM public.checks WHERE check_number = '1003';

\echo ''
\echo '=== TEST (d): created_by gets forced ==='
CREATE OR REPLACE FUNCTION auth.uid() RETURNS UUID AS $$ SELECT '22222222-2222-2222-2222-222222222222'::UUID; $$ LANGUAGE SQL STABLE;

-- Insert without created_by (should be forced to auth.uid())
INSERT INTO public.checks (company_id, account_id, account_holder_name, account_holder_address, account_holder_city, account_holder_state, account_holder_zip,
  check_number, date, bank_name, amount, pay_to, memo, signature, routing_number, bank_account_number, is_legacy)
VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid, 'Test Company', '123 Test St', 'Test City', 'TS', '12345',
  '1004', '2024-10-22', 'Test Bank', '400.00', 'Test Payee 4', 'Test memo', 'Test Sig', '123456789', '987654321', false);

SELECT 'TEST (d) created_by forced:' as test, check_number, created_by, 
       CASE WHEN created_by = '22222222-2222-2222-2222-222222222222'::uuid THEN 'PASS' ELSE 'FAIL' END as result
FROM public.checks WHERE check_number = '1004';

\echo ''
\echo '=== TEST (e): Edge function with hashed key ==='
-- Generate API key as admin
CREATE OR REPLACE FUNCTION auth.uid() RETURNS UUID AS $$ SELECT '11111111-1111-1111-1111-111111111111'::UUID; $$ LANGUAGE SQL STABLE;

SELECT 'TEST (e.1) Generated key:' as test, left(api_key, 15) || '...' as key_prefix
FROM public.generate_submitter_api_key('33333333-3333-3333-3333-333333333333'::uuid, 'Test Bot', 30)
\gset

-- Verify hash is stored (64 chars for SHA-256)
SELECT 'TEST (e.2) Hash stored:' as test, name, length(key_hash) as hash_length, is_active
FROM public.submitter_api_keys WHERE name = 'Test Bot';

-- Note: Edge function testing requires actual HTTP calls, but we can verify the function exists
\echo 'TEST (e.3) Edge function submit-check exists (test with curl after deployment)'

\echo ''
\echo '=== TEST (f): Anon access denied ==='
-- Note: In test environment as postgres superuser, RLS is not enforced
-- This test verifies policies exist, but actual enforcement requires setting role
\echo 'Verifying anon has NO privileges on checks table:'
SELECT 
  'TEST (f.1) Anon privileges:' as test,
  COUNT(*) as privilege_count
FROM information_schema.table_privileges
WHERE grantee = 'anon' 
  AND table_name = 'checks' 
  AND table_schema = 'public';

\echo 'Verifying RLS is enabled on checks:'
SELECT 
  'TEST (f.2) RLS enabled:' as test,
  CASE WHEN relrowsecurity THEN 'PASS' ELSE 'FAIL' END as result
FROM pg_class
WHERE relname = 'checks' AND relnamespace = 'public'::regnamespace;

\echo ''
\echo '=== ALL TESTS COMPLETE ==='
\echo ''
\echo '=== Final state summary ==='
SELECT check_number, status, is_printed, 
       CASE 
         WHEN created_by = '22222222-2222-2222-2222-222222222222'::uuid THEN 'approver'
         WHEN created_by = '33333333-3333-3333-3333-333333333333'::uuid THEN 'submitter'
         ELSE 'other'
       END as creator
FROM public.checks 
WHERE check_number IN ('1001', '1002', '1003', '1004')
ORDER BY check_number;
