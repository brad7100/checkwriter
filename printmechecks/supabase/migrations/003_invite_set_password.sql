-- Invited users must set a password on first login.
-- Add flag to profiles and allow users to clear it via RPC after setting password.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS must_set_password boolean NOT NULL DEFAULT false;

-- User can clear their own must_set_password after setting password (called from app).
CREATE OR REPLACE FUNCTION public.clear_must_set_password()
RETURNS void AS $$
  UPDATE public.profiles
  SET must_set_password = false, updated_at = NOW()
  WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.clear_must_set_password() TO authenticated;
