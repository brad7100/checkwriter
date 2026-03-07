-- Re-enable RLS so per-account permissions are enforced.
-- Run this if invited users can see all accounts (e.g. after 20251005_disable_rls was applied).
-- Requires 001_users_and_permissions.sql policies to be in place.

ALTER TABLE public.companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bank_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.custom_layouts ENABLE ROW LEVEL SECURITY;
