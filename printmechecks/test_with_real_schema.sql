-- Test migrations against REAL production schema
-- This uses the actual column names from production (pay_to, not payee)

\timing on
\set ON_ERROR_STOP on

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create extensions schema (Supabase has this)
CREATE SCHEMA IF NOT EXISTS extensions;
CREATE EXTENSION IF NOT EXISTS "pgcrypto" SCHEMA extensions;

-- Create Supabase roles
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
    CREATE ROLE service_role NOLOGIN;
  END IF;
END $$;

-- Create auth schema
CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS extensions;

CREATE TABLE IF NOT EXISTS auth.users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email TEXT UNIQUE NOT NULL,
  encrypted_password TEXT,
  email_confirmed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Mock auth.uid() function
CREATE OR REPLACE FUNCTION auth.uid() RETURNS UUID AS $$
  SELECT '11111111-1111-1111-1111-111111111111'::UUID;
$$ LANGUAGE SQL STABLE;

\echo '=== Applying initial schema (20251005_initial_schema.sql) ==='
\i /migrations/20251005_initial_schema.sql

\echo '=== Applying 20251005_disable_rls.sql ==='
\i /migrations/20251005_disable_rls.sql

\echo '=== Applying 001_users_and_permissions.sql ==='
\i /migrations/001_users_and_permissions.sql

\echo '=== Applying 002_reenable_rls_for_permissions.sql ==='
\i /migrations/002_reenable_rls_for_permissions.sql

\echo '=== Applying 003_invite_set_password.sql ==='
\i /migrations/003_invite_set_password.sql

\echo '=== Seeding test data with REAL column names ==='

-- Create test users
INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
VALUES 
  ('11111111-1111-1111-1111-111111111111'::uuid, 'brad@bradwilliamslaw.com', extensions.crypt('testpass', extensions.gen_salt('bf')), NOW(), NOW(), NOW()),
  ('22222222-2222-2222-2222-222222222222'::uuid, 'karen@bradwilliamslaw.com', extensions.crypt('testpass', extensions.gen_salt('bf')), NOW(), NOW(), NOW()),
  ('33333333-3333-3333-3333-333333333333'::uuid, 'submitter@bradwilliamslaw.com', extensions.crypt('testpass', extensions.gen_salt('bf')), NOW(), NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- Create profiles (will be updated by migration 005)
INSERT INTO public.profiles (id, email, role)
VALUES 
  ('11111111-1111-1111-1111-111111111111'::uuid, 'brad@bradwilliamslaw.com', 'admin'),
  ('22222222-2222-2222-2222-222222222222'::uuid, 'karen@bradwilliamslaw.com', 'user'),
  ('33333333-3333-3333-3333-333333333333'::uuid, 'submitter@bradwilliamslaw.com', 'user')
ON CONFLICT (id) DO UPDATE SET role = EXCLUDED.role;

-- Create company
INSERT INTO public.companies (id, name, address, city, state, zip)
VALUES 
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid, 'Brad Williams Law', '123 Legal St', 'Springfield', 'IL', '62701')
ON CONFLICT (id) DO NOTHING;

-- Create bank accounts
INSERT INTO public.bank_accounts (id, company_id, name, bank_name, routing_number, account_number, bank_city, signature)
VALUES 
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid, 'Operating Account 7857', 'First National Bank', '071000013', '••••7857', 'Springfield', 'Brad Williams'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb02'::uuid, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid, 'Trust Account 0992', 'Second Bank', '071000013', '••••0992', 'Springfield', 'Brad Williams')
ON CONFLICT (id) DO NOTHING;

-- Grant account access
INSERT INTO public.account_users (bank_account_id, user_id)
VALUES 
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid, '11111111-1111-1111-1111-111111111111'::uuid),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid, '22222222-2222-2222-2222-222222222222'::uuid),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid, '33333333-3333-3333-3333-333333333333'::uuid),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb02'::uuid, '11111111-1111-1111-1111-111111111111'::uuid),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb02'::uuid, '22222222-2222-2222-2222-222222222222'::uuid)
ON CONFLICT DO NOTHING;

-- Create legacy checks with REAL column name: pay_to (not payee!)
\echo '=== Creating 454 printed + 28 unprinted checks with pay_to column ==='
DO $$
DECLARE
  i INTEGER;
  v_check_num TEXT;
  v_account_id UUID;
BEGIN
  -- 454 printed checks
  FOR i IN 1..454 LOOP
    v_account_id := CASE WHEN i % 2 = 0 THEN 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid ELSE 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb02'::uuid END;
    v_check_num := (1000 + i)::TEXT;
    
    INSERT INTO public.checks (
      company_id, account_id, account_holder_name, account_holder_address, 
      account_holder_city, account_holder_state, account_holder_zip,
      check_number, date, bank_name, amount, pay_to, memo, signature,
      routing_number, bank_account_number, is_printed
    ) VALUES (
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid, v_account_id, 'Brad Williams Law', '123 Legal St',
      'Springfield', 'IL', '62701',
      v_check_num, '2024-10-01', 'First National Bank', (100 + i * 10)::TEXT, 'Vendor ' || i, 'Payment ' || i, 'Brad Williams',
      '071000013', '12345678', true
    );
  END LOOP;
  
  -- 28 unprinted checks
  FOR i IN 1..28 LOOP
    INSERT INTO public.checks (
      company_id, account_id, account_holder_name, account_holder_address,
      account_holder_city, account_holder_state, account_holder_zip,
      check_number, date, bank_name, amount, pay_to, memo, signature,
      routing_number, bank_account_number, is_printed
    ) VALUES (
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid, 'Brad Williams Law', '123 Legal St',
      'Springfield', 'IL', '62701',
      (2000 + i)::TEXT, '2024-10-15', 'First National Bank', (200 + i * 15)::TEXT, 'Pending Vendor ' || i, 'Ready to print', 'Brad Williams',
      '071000013', '12345678', false
    );
  END LOOP;
END $$;

\echo '=== Pre-migration check count ==='
SELECT is_printed, COUNT(*) FROM public.checks GROUP BY is_printed;

\echo '=== Applying 004_security_lockdown.sql ==='
\i /migrations/004_security_lockdown.sql

\echo '=== Applying 005_approval_workflow.sql ==='
\i /migrations/005_approval_workflow.sql

\echo '=== Applying 006_submitter_api_keys.sql ==='
\i /migrations/006_submitter_api_keys.sql

\echo '=== MIGRATIONS COMPLETE ==='

\echo '=== Post-migration status summary ==='
SELECT 
  status, 
  is_legacy,
  is_printed,
  COUNT(*) as count
FROM public.checks
GROUP BY status, is_legacy, is_printed
ORDER BY status, is_legacy;

\echo '=== Test 1: Approver (Karen) inserts check with status=printed (should succeed) ==='
-- Change auth.uid() to Karen
CREATE OR REPLACE FUNCTION auth.uid() RETURNS UUID AS $$
  SELECT '22222222-2222-2222-2222-222222222222'::UUID;
$$ LANGUAGE SQL STABLE;

BEGIN;
INSERT INTO public.checks (
  company_id, account_id, account_holder_name, account_holder_address,
  account_holder_city, account_holder_state, account_holder_zip,
  check_number, date, bank_name, amount, pay_to, memo, signature,
  routing_number, bank_account_number, status, created_by, is_legacy
) VALUES (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid, 
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid,
  'Brad Williams Law', '123 Legal St', 'Springfield', 'IL', '62701',
  '5001', '2024-10-22', 'First National Bank', '500.00', 'Test Approver Insert', 
  'Karen direct print', 'Brad Williams', '071000013', '12345678',
  'printed', '22222222-2222-2222-2222-222222222222'::uuid, false
);
SELECT 'Test 1 Result:' as test, status, pay_to FROM public.checks WHERE check_number = '5001';
COMMIT;

\echo '=== Test 2: Submitter inserts check with status=printed (should coerce to pending) ==='
CREATE OR REPLACE FUNCTION auth.uid() RETURNS UUID AS $$
  SELECT '33333333-3333-3333-3333-333333333333'::UUID;
$$ LANGUAGE SQL STABLE;

BEGIN;
INSERT INTO public.checks (
  company_id, account_id, account_holder_name, account_holder_address,
  account_holder_city, account_holder_state, account_holder_zip,
  check_number, date, bank_name, amount, pay_to, memo, signature,
  routing_number, bank_account_number, status, created_by, is_legacy
) VALUES (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid,
  'Brad Williams Law', '123 Legal St', 'Springfield', 'IL', '62701',
  '5002', '2024-10-22', 'First National Bank', '300.00', 'Test Submitter Insert',
  'Should be pending', 'Brad Williams', '071000013', '12345678',
  'printed', '33333333-3333-3333-3333-333333333333'::uuid, false
);
SELECT 'Test 2 Result (should be pending):' as test, status, pay_to FROM public.checks WHERE check_number = '5002';
COMMIT;

\echo '=== Test 3: Generate API key and test hashing ==='
-- Switch to Brad (admin) to generate key
CREATE OR REPLACE FUNCTION auth.uid() RETURNS UUID AS $$
  SELECT '11111111-1111-1111-1111-111111111111'::UUID;
$$ LANGUAGE SQL STABLE;

SELECT 'Test 3 Result:' as test, key_id, name, left(api_key, 10) || '...' as api_key_prefix
FROM public.generate_submitter_api_key(
  '33333333-3333-3333-3333-333333333333'::uuid,
  'Test Bot Key',
  30
);

\echo '=== Test 4: Verify key is hashed in database (SHA-256 = 64 hex chars) ==='
SELECT 
  'Test 4 Result:' as test,
  name, 
  left(key_hash, 16) || '...' as key_hash_prefix,
  length(key_hash) as hash_length,
  is_active
FROM public.submitter_api_keys
WHERE name = 'Test Bot Key';

\echo '=== Test 5: Approver (Karen) deletes a check (should succeed) ==='
CREATE OR REPLACE FUNCTION auth.uid() RETURNS UUID AS $$
  SELECT '22222222-2222-2222-2222-222222222222'::UUID;
$$ LANGUAGE SQL STABLE;

BEGIN;
DELETE FROM public.checks WHERE check_number = '5001';
SELECT 'Test 5 Result:' as test, COUNT(*) as remaining_count FROM public.checks WHERE check_number = '5001';
ROLLBACK;

\echo '=== All tests complete! ==='
