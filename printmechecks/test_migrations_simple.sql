-- Simplified test migrations script
-- Tests the new migrations (004, 005, 006) against a minimal existing schema

\timing on
\set ON_ERROR_STOP on

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create minimal auth schema (simulating Supabase)
CREATE SCHEMA IF NOT EXISTS auth;

-- Create Supabase roles (simulating Supabase environment)
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

-- Create minimal existing schema (pre-PR #2)
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT UNIQUE NOT NULL,
  role TEXT NOT NULL DEFAULT 'submitter' CHECK (role IN ('admin', 'approver', 'submitter')),
  can_self_approve BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.companies (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  address TEXT,
  city TEXT,
  state TEXT,
  zip TEXT,
  owner_id UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.bank_accounts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  bank_name TEXT,
  routing_number TEXT,
  account_number TEXT,
  bank_city TEXT,
  signature TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.account_users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  bank_account_id UUID REFERENCES public.bank_accounts(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(bank_account_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.checks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  account_id UUID REFERENCES public.bank_accounts(id),
  check_number TEXT NOT NULL,
  payee TEXT,
  amount NUMERIC(10, 2),
  memo TEXT,
  date DATE,
  is_printed BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Basic helper functions
CREATE OR REPLACE FUNCTION public.is_admin() RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() AND role = 'admin'
  );
$$ LANGUAGE SQL STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.can_approve_checks() RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() AND role IN ('admin', 'approver')
  );
$$ LANGUAGE SQL STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.get_user_role() RETURNS TEXT AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE SQL STABLE SECURITY DEFINER;

\echo '=== Base schema ready ==='

-- Seed test data BEFORE applying new migrations
\echo '=== Seeding existing production data ==='

-- Create test users
INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
VALUES 
  ('11111111-1111-1111-1111-111111111111'::uuid, 'brad@bradwilliamslaw.com', crypt('testpass', gen_salt('bf')), NOW(), NOW(), NOW()),
  ('22222222-2222-2222-2222-222222222222'::uuid, 'karen@bradwilliamslaw.com', crypt('testpass', gen_salt('bf')), NOW(), NOW(), NOW()),
  ('33333333-3333-3333-3333-333333333333'::uuid, 'submitter@bradwilliamslaw.com', crypt('testpass', gen_salt('bf')), NOW(), NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- Create profiles
INSERT INTO public.profiles (id, email, role, can_self_approve)
VALUES 
  ('11111111-1111-1111-1111-111111111111'::uuid, 'brad@bradwilliamslaw.com', 'admin', true),
  ('22222222-2222-2222-2222-222222222222'::uuid, 'karen@bradwilliamslaw.com', 'approver', true),
  ('33333333-3333-3333-3333-333333333333'::uuid, 'submitter@bradwilliamslaw.com', 'submitter', false)
ON CONFLICT (id) DO UPDATE SET role = EXCLUDED.role;

-- Create company
INSERT INTO public.companies (id, name, address, city, state, zip, owner_id)
VALUES 
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid, 'Brad Williams Law', '123 Legal St', 'Springfield', 'IL', '62701', '11111111-1111-1111-1111-111111111111'::uuid)
ON CONFLICT (id) DO NOTHING;

-- Create bank accounts (matching production)
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
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb02'::uuid, '11111111-1111-1111-1111-111111111111'::uuid),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb02'::uuid, '22222222-2222-2222-2222-222222222222'::uuid)
ON CONFLICT DO NOTHING;

-- Create 454 printed checks + 28 unprinted, INCLUDING DUPLICATES
\echo '=== Creating 454 legacy printed checks with duplicates ==='
DO $$
DECLARE
  i INTEGER;
  v_check_num TEXT;
  v_account_id UUID;
BEGIN
  -- Account 7857: checks 1000-1226 (227 checks * 2 = 454)
  FOR i IN 0..226 LOOP
    v_check_num := (1000 + i)::TEXT;
    v_account_id := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid;
    
    -- Create duplicates for #1372 and #1394
    IF v_check_num IN ('1372', '1394') THEN
      -- First instance
      INSERT INTO public.checks (account_id, check_number, payee, amount, memo, date, is_printed)
      VALUES (v_account_id, v_check_num, 'Vendor ' || i, (100 + i * 10)::NUMERIC, 'Payment ' || i, CURRENT_DATE - i, true);
      -- Second instance (duplicate)
      INSERT INTO public.checks (account_id, check_number, payee, amount, memo, date, is_printed)
      VALUES (v_account_id, v_check_num, 'Vendor ' || i || ' Dup', (100 + i * 10)::NUMERIC, 'Duplicate', CURRENT_DATE - i, true);
    ELSE
      INSERT INTO public.checks (account_id, check_number, payee, amount, memo, date, is_printed)
      VALUES (v_account_id, v_check_num, 'Vendor ' || i, (100 + i * 10)::NUMERIC, 'Payment ' || i, CURRENT_DATE - i, true);
    END IF;
  END LOOP;
  
  -- Account 0992: checks 20000-20226
  FOR i IN 0..226 LOOP
    v_check_num := (20000 + i)::TEXT;
    v_account_id := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb02'::uuid;
    
    -- Create duplicate for #20025
    IF v_check_num = '20025' THEN
      -- First instance
      INSERT INTO public.checks (account_id, check_number, payee, amount, memo, date, is_printed)
      VALUES (v_account_id, v_check_num, 'Trust Payee ' || i, (500 + i * 5)::NUMERIC, 'Trust payment ' || i, CURRENT_DATE - i, true);
      -- Second instance (duplicate)
      INSERT INTO public.checks (account_id, check_number, payee, amount, memo, date, is_printed)
      VALUES (v_account_id, v_check_num, 'Trust Payee ' || i || ' Dup', (500 + i * 5)::NUMERIC, 'Duplicate trust', CURRENT_DATE - i, true);
    ELSE
      INSERT INTO public.checks (account_id, check_number, payee, amount, memo, date, is_printed)
      VALUES (v_account_id, v_check_num, 'Trust Payee ' || i, (500 + i * 5)::NUMERIC, 'Trust payment ' || i, CURRENT_DATE - i, true);
    END IF;
  END LOOP;
END $$;

\echo '=== Creating 28 unprinted checks (to become approved) ==='
DO $$
DECLARE
  i INTEGER;
BEGIN
  FOR i IN 1..28 LOOP
    INSERT INTO public.checks (account_id, check_number, payee, amount, memo, date, is_printed)
    VALUES (
      'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb01'::uuid,
      (2000 + i)::TEXT,
      'Pending Vendor ' || i,
      (200 + i * 15)::NUMERIC,
      'Ready to print ' || i,
      CURRENT_DATE + i,
      false
    );
  END LOOP;
END $$;

\echo '=== Pre-migration check count ==='
SELECT is_printed, COUNT(*) FROM public.checks GROUP BY is_printed;

\echo '=== Pre-migration duplicates (should be 3 pairs) ==='
SELECT account_id, check_number, COUNT(*) 
FROM public.checks 
GROUP BY account_id, check_number 
HAVING COUNT(*) > 1;

-- NOW APPLY THE NEW MIGRATIONS
\echo '=== Applying 004_security_lockdown.sql (idempotent) ==='
\i /migrations/004_security_lockdown.sql

\echo '=== Applying 005_approval_workflow.sql ==='
\i /migrations/005_approval_workflow.sql

\echo '=== Applying 006_submitter_api_keys.sql ==='
\i /migrations/006_submitter_api_keys.sql

\echo '=== MIGRATIONS COMPLETE ==='

-- Verify results
\echo '=== Post-migration check status summary ==='
SELECT 
  status, 
  is_legacy,
  is_printed,
  COUNT(*) as count,
  COUNT(created_by) as has_creator
FROM public.checks
GROUP BY status, is_legacy, is_printed
ORDER BY status, is_legacy;

\echo '=== Post-migration duplicates (should still be 3 pairs, all legacy) ==='
SELECT 
  account_id,
  check_number,
  is_legacy,
  COUNT(*) as occurrences
FROM public.checks
GROUP BY account_id, check_number, is_legacy
HAVING COUNT(*) > 1
ORDER BY account_id, check_number;

\echo '=== Verify unique index on non-legacy checks ==='
SELECT 
  indexname, 
  indexdef 
FROM pg_indexes 
WHERE tablename = 'checks' 
  AND indexname LIKE '%unique%';

\echo '=== Test complete! All migrations applied successfully. ==='
