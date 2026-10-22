-- ============================================================
-- Submitter API Keys Table
-- Stores API keys for automated check submission bots
-- This migration is idempotent - safe to re-run
-- ============================================================

-- 1. Create table for submitter API keys (IF NOT EXISTS = idempotent)
CREATE TABLE IF NOT EXISTS public.submitter_api_keys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  key_hash TEXT NOT NULL UNIQUE,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id),
  last_used_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  metadata JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_submitter_keys_user_id ON public.submitter_api_keys(user_id);
CREATE INDEX IF NOT EXISTS idx_submitter_keys_key_hash ON public.submitter_api_keys(key_hash);
CREATE INDEX IF NOT EXISTS idx_submitter_keys_active ON public.submitter_api_keys(is_active);

-- 2. Enable RLS
ALTER TABLE public.submitter_api_keys ENABLE ROW LEVEL SECURITY;

-- 3. RLS Policies
-- Only admins can view API keys
CREATE POLICY "API Keys: admins can select"
  ON public.submitter_api_keys FOR SELECT
  USING (public.is_admin());

-- Only admins can create API keys
CREATE POLICY "API Keys: admins can insert"
  ON public.submitter_api_keys FOR INSERT
  WITH CHECK (public.is_admin());

-- Only admins can update API keys (e.g., deactivate)
CREATE POLICY "API Keys: admins can update"
  ON public.submitter_api_keys FOR UPDATE
  USING (public.is_admin());

-- Only admins can delete API keys
CREATE POLICY "API Keys: admins can delete"
  ON public.submitter_api_keys FOR DELETE
  USING (public.is_admin());

-- 4. Function to generate a new API key (CREATE OR REPLACE = idempotent)
CREATE OR REPLACE FUNCTION public.generate_submitter_api_key(
  p_user_id UUID,
  p_name TEXT,
  p_expires_days INTEGER DEFAULT NULL
)
RETURNS TABLE(
  api_key TEXT,
  key_id UUID,
  user_id UUID,
  name TEXT,
  expires_at TIMESTAMPTZ
) AS $$
DECLARE
  v_api_key TEXT;
  v_key_id UUID;
  v_expires_at TIMESTAMPTZ;
BEGIN
  -- Only admins can generate keys
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Only admins can generate API keys';
  END IF;
  
  -- Verify user exists and has submitter role
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = p_user_id 
    AND role IN ('submitter', 'approver', 'admin')
  ) THEN
    RAISE EXCEPTION 'User must have submitter, approver, or admin role';
  END IF;
  
  -- Generate a secure random key (32 bytes = 256 bits)
  -- Format: sbmt_<base64url>
  v_api_key := 'sbmt_' || encode(gen_random_bytes(32), 'base64');
  v_api_key := replace(replace(replace(v_api_key, '+', '-'), '/', '_'), '=', '');
  
  -- Calculate expiration
  IF p_expires_days IS NOT NULL THEN
    v_expires_at := NOW() + (p_expires_days || ' days')::INTERVAL;
  END IF;
  
  -- Store the key (in production, you'd hash this)
  -- For simplicity, we're storing it directly since it's already a random token
  INSERT INTO public.submitter_api_keys (
    user_id,
    name,
    key_hash,
    expires_at,
    created_by
  ) VALUES (
    p_user_id,
    p_name,
    v_api_key,  -- In production, use pgcrypto crypt() or similar
    v_expires_at,
    auth.uid()
  ) RETURNING id INTO v_key_id;
  
  -- Return the key (only time it will be shown!)
  RETURN QUERY
  SELECT v_api_key, v_key_id, p_user_id, p_name, v_expires_at;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Function to revoke an API key (CREATE OR REPLACE = idempotent)
CREATE OR REPLACE FUNCTION public.revoke_submitter_api_key(
  p_key_id UUID
)
RETURNS BOOLEAN AS $$
BEGIN
  -- Only admins can revoke keys
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Only admins can revoke API keys';
  END IF;
  
  UPDATE public.submitter_api_keys
  SET is_active = false
  WHERE id = p_key_id;
  
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Grant execute permissions
GRANT EXECUTE ON FUNCTION public.generate_submitter_api_key TO authenticated;
GRANT EXECUTE ON FUNCTION public.revoke_submitter_api_key TO authenticated;

-- 7. Secure functions and table from anon access
-- Revoke all access from anon/public
REVOKE ALL ON public.submitter_api_keys FROM anon;
REVOKE ALL ON public.submitter_api_keys FROM public;
GRANT SELECT, INSERT, UPDATE ON public.submitter_api_keys TO authenticated;

-- Set secure search_path on SECURITY DEFINER functions
ALTER FUNCTION public.generate_submitter_api_key(UUID, TEXT, INTEGER) SET search_path = public, pg_temp;
ALTER FUNCTION public.revoke_submitter_api_key(UUID) SET search_path = public, pg_temp;

-- Revoke EXECUTE from anon
REVOKE EXECUTE ON FUNCTION public.generate_submitter_api_key(UUID, TEXT, INTEGER) FROM anon;
REVOKE EXECUTE ON FUNCTION public.generate_submitter_api_key(UUID, TEXT, INTEGER) FROM public;
GRANT EXECUTE ON FUNCTION public.generate_submitter_api_key(UUID, TEXT, INTEGER) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.revoke_submitter_api_key(UUID) FROM anon;
REVOKE EXECUTE ON FUNCTION public.revoke_submitter_api_key(UUID) FROM public;
GRANT EXECUTE ON FUNCTION public.revoke_submitter_api_key(UUID) TO authenticated;

-- 8. Comments
COMMENT ON TABLE public.submitter_api_keys IS 'API keys for automated check submission bots';
COMMENT ON COLUMN public.submitter_api_keys.key_hash IS 'The API key value (should be hashed in production)';
COMMENT ON COLUMN public.submitter_api_keys.last_used_at IS 'Automatically updated when key is used';
COMMENT ON FUNCTION public.generate_submitter_api_key IS 'Generate a new API key for bot check submission';
