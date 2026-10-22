-- Test migrations script
-- This script applies all migrations and seeds realistic test data

\timing on
\set ON_ERROR_STOP on

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Apply base migrations
\echo '=== Applying 20251005_initial_schema.sql ==='
\i /migrations/20251005_initial_schema.sql

\echo '=== Applying 20251005_disable_rls.sql ==='
\i /migrations/20251005_disable_rls.sql

\echo '=== Applying 001_users_and_permissions.sql ==='
\i /migrations/001_users_and_permissions.sql

\echo '=== Applying 002_reenable_rls_for_permissions.sql ==='
\i /migrations/002_reenable_rls_for_permissions.sql

\echo '=== Applying 003_invite_set_password.sql ==='
\i /migrations/003_invite_set_password.sql

\echo '=== Applying 004_security_lockdown.sql ==='
\i /migrations/004_security_lockdown.sql

\echo '=== Applying 005_approval_workflow.sql ==='
\i /migrations/005_approval_workflow.sql

\echo '=== Applying 006_submitter_api_keys.sql ==='
\i /migrations/006_submitter_api_keys.sql

\echo '=== Migrations applied successfully! ==='

-- Seed test data
\echo '=== Seeding test data ==='

-- Create test users (simulating Supabase Auth)
-- Brad (admin)
INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
VALUES 
  ('11111111-1111-1111-1111-111111111111'::uuid, 'brad@bradwilliamslaw.com', crypt('testpass', gen_salt('bf')), NOW(), NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- Karen (approver)
INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
VALUES 
  ('22222222-2222-2222-2222-222222222222'::uuid, 'karen@bradwilliamslaw.com', crypt('testpass', gen_salt('bf')), NOW(), NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- Submitter user
INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
VALUES 
  ('33333333-3333-3333-3333-333333333333'::uuid, 'submitter@bradwilliamslaw.com', crypt('testpass', gen_salt('bf')), NOW(), NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- Bot user
INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
VALUES 
  ('44444444-4444-4444-4444-444444444444'::uuid, 'bot@bradwilliamslaw.com', crypt('testpass', gen_salt('bf')), NOW(), NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- Create profiles
INSERT INTO public.profiles (id, email, role, can_self_approve)
VALUES 
  ('11111111-1111-1111-1111-111111111111'::uuid, 'brad@bradwilliamslaw.com', 'admin', true),
  ('22222222-2222-2222-2222-222222222222'::uuid, 'karen@bradwilliamslaw.com', 'approver', true),
  ('33333333-3333-3333-3333-333333333333'::uuid, 'submitter@bradwilliamslaw.com', 'submitter', false),
  ('44444444-4444-4444-4444-444444444444'::uuid, 'bot@bradwilliamslaw.com', 'submitter', false)
ON CONFLICT (id) DO UPDATE SET
  role = EXCLUDED.role,
  can_self_approve = EXCLUDED.can_self_approve;

-- Create companies
INSERT INTO public.companies (id, name, address, city, state, zip, owner_id)
VALUES 
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid, 'Brad Williams Law', '123 Legal St', 'Springfield', 'IL', '62701', '11111111-1111-1111-1111-111111111111'::uuid)
ON CONFLICT (id) DO NOTHING;

-- Create bank accounts (matching production: accounts ending 7857 and 0992)
INSERT INTO public.bank_accounts (id, company_id, name, bank_name, routing_number, account_number, bank_city, signature)
VALUES 
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid, 'Operating Account 7857', 'First National Bank', '071000013', '••••7857', 'Springfield', 'Brad Williams'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb02'::uuid, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid, 'Trust Account 0992', 'Second Bank', '071000013', '••••0992', 'Springfield', 'Brad Williams')
ON CONFLICT (id) DO NOTHING;

-- Grant account access to all users
INSERT INTO public.account_users (bank_account_id, user_id)
VALUES 
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid, '11111111-1111-1111-1111-111111111111'::uuid),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid, '22222222-2222-2222-2222-222222222222'::uuid),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid, '33333333-3333-3333-3333-333333333333'::uuid),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb02'::uuid, '11111111-1111-1111-1111-111111111111'::uuid),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb02'::uuid, '22222222-2222-2222-2222-222222222222'::uuid),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb02'::uuid, '33333333-3333-3333-3333-333333333333'::uuid)
ON CONFLICT DO NOTHING;

-- Seed legacy checks (simulating 482 existing production checks)
-- 454 printed checks + 28 unprinted (approved)
-- Including the duplicates mentioned: account 7857 has #1372 twice, #1394 twice; account 0992 has #20025 twice

\echo '=== Creating 454 legacy printed checks ==='
DO $$
DECLARE
  i INTEGER;
  v_check_num TEXT;
  v_account_id UUID;
BEGIN
  FOR i IN 1..227 LOOP
    v_check_num := (1000 + i)::TEXT;
    v_account_id := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid;
    
    -- Create duplicates for account 7857
    IF i = 372 OR i = 394 THEN
      -- First instance
      INSERT INTO public.checks (
        account_id, check_number, payee, amount, memo, date, 
        status, is_printed, created_by, is_legacy
      ) VALUES (
        v_account_id, v_check_num, 'Vendor ' || i, (100 + i * 10)::NUMERIC, 'Payment ' || i, CURRENT_DATE - (i || ' days')::INTERVAL,
        'printed', true, NULL, true
      );
      -- Second instance (duplicate)
      INSERT INTO public.checks (
        account_id, check_number, payee, amount, memo, date,
        status, is_printed, created_by, is_legacy
      ) VALUES (
        v_account_id, v_check_num, 'Vendor ' || i || ' Dup', (100 + i * 10)::NUMERIC, 'Duplicate payment', CURRENT_DATE - (i || ' days')::INTERVAL,
        'printed', true, NULL, true
      );
    ELSE
      INSERT INTO public.checks (
        account_id, check_number, payee, amount, memo, date,
        status, is_printed, created_by, is_legacy
      ) VALUES (
        v_account_id, v_check_num, 'Vendor ' || i, (100 + i * 10)::NUMERIC, 'Payment ' || i, CURRENT_DATE - (i || ' days')::INTERVAL,
        'printed', true, NULL, true
      );
    END IF;
  END LOOP;
  
  -- Account 0992 checks with one duplicate
  FOR i IN 1..227 LOOP
    v_check_num := (20000 + i)::TEXT;
    v_account_id := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb02'::uuid;
    
    -- Create duplicate for check 20025
    IF i = 25 THEN
      -- First instance
      INSERT INTO public.checks (
        account_id, check_number, payee, amount, memo, date,
        status, is_printed, created_by, is_legacy
      ) VALUES (
        v_account_id, v_check_num, 'Trust Payee ' || i, (500 + i * 5)::NUMERIC, 'Trust payment ' || i, CURRENT_DATE - (i || ' days')::INTERVAL,
        'printed', true, NULL, true
      );
      -- Second instance (duplicate)
      INSERT INTO public.checks (
        account_id, check_number, payee, amount, memo, date,
        status, is_printed, created_by, is_legacy
      ) VALUES (
        v_account_id, v_check_num, 'Trust Payee ' || i || ' Dup', (500 + i * 5)::NUMERIC, 'Duplicate trust payment', CURRENT_DATE - (i || ' days')::INTERVAL,
        'printed', true, NULL, true
      );
    ELSE
      INSERT INTO public.checks (
        account_id, check_number, payee, amount, memo, date,
        status, is_printed, created_by, is_legacy
      ) VALUES (
        v_account_id, v_check_num, 'Trust Payee ' || i, (500 + i * 5)::NUMERIC, 'Trust payment ' || i, CURRENT_DATE - (i || ' days')::INTERVAL,
        'printed', true, NULL, true
      );
    END IF;
  END LOOP;
END $$;

\echo '=== Creating 28 legacy unprinted (approved) checks ==='
DO $$
DECLARE
  i INTEGER;
BEGIN
  FOR i IN 1..28 LOOP
    INSERT INTO public.checks (
      account_id, check_number, payee, amount, memo, date,
      status, is_printed, created_by, is_legacy
    ) VALUES (
      'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid, 
      (2000 + i)::TEXT,
      'Pending Vendor ' || i,
      (200 + i * 15)::NUMERIC,
      'Ready to print ' || i,
      CURRENT_DATE + (i || ' days')::INTERVAL,
      'approved',
      false,
      NULL,
      true
    );
  END LOOP;
END $$;

\echo '=== Test data seeded successfully! ==='
\echo '=== Summary ==='
SELECT 
  status, 
  is_legacy,
  is_printed,
  COUNT(*) as count
FROM public.checks
GROUP BY status, is_legacy, is_printed
ORDER BY status, is_legacy, is_printed;

\echo '=== Duplicate check numbers (expected: 3 pairs) ==='
SELECT 
  account_id,
  check_number,
  COUNT(*) as occurrences
FROM public.checks
WHERE is_legacy = true
GROUP BY account_id, check_number
HAVING COUNT(*) > 1
ORDER BY account_id, check_number;

\echo '=== All tests ready! ==='
