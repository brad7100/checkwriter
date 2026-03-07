-- ============================================================
-- Users & per-account permissions for Checkwriter
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor → New query)
-- ============================================================

-- 1. Profiles: one row per auth user (role: 'admin' | 'user')
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('admin', 'user')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Which users can use which bank accounts (non-admin users only see these)
CREATE TABLE IF NOT EXISTS public.account_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  bank_account_id UUID NOT NULL REFERENCES public.bank_accounts(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, bank_account_id)
);

CREATE INDEX IF NOT EXISTS idx_account_users_user_id ON public.account_users(user_id);
CREATE INDEX IF NOT EXISTS idx_account_users_bank_account_id ON public.account_users(bank_account_id);

-- 3. Create profile when a new user signs up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, role)
  VALUES (NEW.id, COALESCE(NEW.email, ''), 'user')
  ON CONFLICT (id) DO UPDATE SET email = COALESCE(NEW.email, ''), updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 4. Backfill existing auth users into profiles (run once)
INSERT INTO public.profiles (id, email, role)
SELECT id, email, 'user'
FROM auth.users
ON CONFLICT (id) DO NOTHING;

-- 5. Enable RLS on all relevant tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.account_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bank_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.custom_layouts ENABLE ROW LEVEL SECURITY;

-- 6. Helper: is current user an admin?
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- 7. Profiles policies
CREATE POLICY "Users can read own profile"
  ON public.profiles FOR SELECT
  USING (id = auth.uid());

CREATE POLICY "Admins can read all profiles"
  ON public.profiles FOR SELECT
  USING (public.is_admin());

CREATE POLICY "Admins can update any profile (e.g. set role)"
  ON public.profiles FOR UPDATE
  USING (public.is_admin());

-- 8. account_users policies
CREATE POLICY "Users can read own account access"
  ON public.account_users FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Admins can read all account_users"
  ON public.account_users FOR SELECT
  USING (public.is_admin());

CREATE POLICY "Admins can insert account_users"
  ON public.account_users FOR INSERT
  WITH CHECK (public.is_admin());

CREATE POLICY "Admins can delete account_users"
  ON public.account_users FOR DELETE
  USING (public.is_admin());

-- 9. companies: select only if admin or has access to at least one account of that company
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

CREATE POLICY "Companies: insert/update/delete admin only"
  ON public.companies FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- 10. bank_accounts: select if admin or in account_users
CREATE POLICY "Bank accounts: select if admin or allowed"
  ON public.bank_accounts FOR SELECT
  USING (
    public.is_admin()
    OR EXISTS (SELECT 1 FROM public.account_users WHERE user_id = auth.uid() AND bank_account_id = bank_accounts.id)
  );

CREATE POLICY "Bank accounts: insert/update/delete admin only"
  ON public.bank_accounts FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- 11. checks: select/insert/update/delete if admin or account is in account_users
CREATE POLICY "Checks: select if admin or account access"
  ON public.checks FOR SELECT
  USING (
    public.is_admin()
    OR EXISTS (SELECT 1 FROM public.account_users WHERE user_id = auth.uid() AND bank_account_id = checks.account_id)
  );

CREATE POLICY "Checks: insert if admin or account access"
  ON public.checks FOR INSERT
  WITH CHECK (
    public.is_admin()
    OR EXISTS (SELECT 1 FROM public.account_users WHERE user_id = auth.uid() AND bank_account_id = checks.account_id)
  );

CREATE POLICY "Checks: update/delete if admin or account access"
  ON public.checks FOR UPDATE
  USING (
    public.is_admin()
    OR EXISTS (SELECT 1 FROM public.account_users WHERE user_id = auth.uid() AND bank_account_id = checks.account_id)
  );

CREATE POLICY "Checks: delete if admin or account access"
  ON public.checks FOR DELETE
  USING (
    public.is_admin()
    OR EXISTS (SELECT 1 FROM public.account_users WHERE user_id = auth.uid() AND bank_account_id = checks.account_id)
  );

-- 12. custom_layouts: authenticated users can read all (shared layouts)
CREATE POLICY "Custom layouts: authenticated read"
  ON public.custom_layouts FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Custom layouts: admin write"
  ON public.custom_layouts FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- ============================================================
-- MAKE YOURSELF ADMIN (run after the above, replace with your email)
-- ============================================================
-- UPDATE public.profiles SET role = 'admin' WHERE email = 'your@email.com';
