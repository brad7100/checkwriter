-- ============================================================
-- Approval Workflow Migration
-- Adds check status lifecycle, role extensions, audit trail, 
-- duplicate protection, and separation of duties
-- ============================================================

-- 1. Extend profiles table with additional roles
-- Add 'submitter' and 'approver' roles in addition to 'admin' and 'user'
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE public.profiles 
  ADD CONSTRAINT profiles_role_check 
  CHECK (role IN ('admin', 'user', 'submitter', 'approver'));

-- Add a column to track if user can self-approve (admin override)
-- Not used for approvers - they can always approve/print their own checks
ALTER TABLE public.profiles 
  ADD COLUMN IF NOT EXISTS can_self_approve BOOLEAN DEFAULT false;

-- Backfill existing users with appropriate roles
-- This is idempotent - uses ON CONFLICT DO UPDATE
DO $$
BEGIN
  -- Make brad@bradwilliamslaw.com an admin
  UPDATE public.profiles 
  SET role = 'admin', updated_at = NOW()
  WHERE email = 'brad@bradwilliamslaw.com' 
    AND role != 'admin';
  
  -- Make karen@bradwilliamslaw.com an approver
  UPDATE public.profiles 
  SET role = 'approver', updated_at = NOW()
  WHERE email = 'karen@bradwilliamslaw.com' 
    AND role != 'approver';
  
  -- Make all other non-admin users submitters
  -- (users who are not brad or karen and not already admin)
  UPDATE public.profiles 
  SET role = 'submitter', updated_at = NOW()
  WHERE email NOT IN ('brad@bradwilliamslaw.com', 'karen@bradwilliamslaw.com')
    AND role NOT IN ('admin', 'submitter', 'approver');
    
  RAISE NOTICE 'User roles backfilled: brad=admin, karen=approver, others=submitter';
END $$;

-- 2. Add check status and workflow fields to checks table
-- Use default 'printed' for existing checks to preserve their state
ALTER TABLE public.checks 
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'printed' 
    CHECK (status IN ('pending', 'approved', 'rejected', 'printed', 'void'));

-- For existing checks, ensure status is set based on is_printed flag
DO $$
BEGIN
  -- Set status to 'printed' for all existing checks that were printed
  UPDATE public.checks 
  SET status = 'printed'
  WHERE status IS NULL 
    OR (status = 'printed' AND is_printed = true);
  
  -- Any existing checks that weren't printed should be 'approved' (rare edge case)
  UPDATE public.checks 
  SET status = 'approved'
  WHERE is_printed = false 
    AND status = 'printed';
    
  RAISE NOTICE 'Existing checks backfilled: printed checks marked as status=printed';
END $$;

ALTER TABLE public.checks 
  ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id);

ALTER TABLE public.checks 
  ADD COLUMN IF NOT EXISTS approved_by UUID REFERENCES auth.users(id);

ALTER TABLE public.checks 
  ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ;

ALTER TABLE public.checks 
  ADD COLUMN IF NOT EXISTS rejected_by UUID REFERENCES auth.users(id);

ALTER TABLE public.checks 
  ADD COLUMN IF NOT EXISTS rejected_at TIMESTAMPTZ;

ALTER TABLE public.checks 
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

ALTER TABLE public.checks 
  ADD COLUMN IF NOT EXISTS voided_by UUID REFERENCES auth.users(id);

ALTER TABLE public.checks 
  ADD COLUMN IF NOT EXISTS voided_at TIMESTAMPTZ;

ALTER TABLE public.checks 
  ADD COLUMN IF NOT EXISTS void_reason TEXT;

ALTER TABLE public.checks 
  ADD COLUMN IF NOT EXISTS reprint_count INTEGER DEFAULT 0;

ALTER TABLE public.checks 
  ADD COLUMN IF NOT EXISTS last_reprinted_by UUID REFERENCES auth.users(id);

ALTER TABLE public.checks 
  ADD COLUMN IF NOT EXISTS last_reprinted_at TIMESTAMPTZ;

-- Business category field (already exists as expense_category, but add if missing)
ALTER TABLE public.checks 
  ADD COLUMN IF NOT EXISTS business_unit TEXT;

-- 3. Create audit log table for check changes
CREATE TABLE IF NOT EXISTS public.check_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  check_id UUID NOT NULL REFERENCES public.checks(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id),
  action TEXT NOT NULL CHECK (action IN (
    'created', 'edited', 'approved', 'rejected', 'printed', 
    'reprinted', 'voided', 'submitted'
  )),
  changes JSONB,
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_log_check_id ON public.check_audit_log(check_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_user_id ON public.check_audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_action ON public.check_audit_log(action);
CREATE INDEX IF NOT EXISTS idx_audit_log_created_at ON public.check_audit_log(created_at);

-- 4. Create duplicate detection table for recent checks
CREATE TABLE IF NOT EXISTS public.check_duplicates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id UUID NOT NULL REFERENCES public.bank_accounts(id) ON DELETE CASCADE,
  payee TEXT NOT NULL,
  amount TEXT NOT NULL,
  check_id UUID NOT NULL REFERENCES public.checks(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_duplicates_account_payee_amount 
  ON public.check_duplicates(account_id, payee, amount);
CREATE INDEX IF NOT EXISTS idx_duplicates_created_at 
  ON public.check_duplicates(created_at);

-- 5. Create indexes for check status queries
CREATE INDEX IF NOT EXISTS idx_checks_status ON public.checks(status);
CREATE INDEX IF NOT EXISTS idx_checks_created_by ON public.checks(created_by);
CREATE INDEX IF NOT EXISTS idx_checks_approved_by ON public.checks(approved_by);
CREATE INDEX IF NOT EXISTS idx_checks_approved_at ON public.checks(approved_at);

-- 6. Ensure check numbers are unique per account
CREATE UNIQUE INDEX IF NOT EXISTS idx_checks_unique_number_per_account 
  ON public.checks(account_id, check_number) 
  WHERE status != 'void';

-- 7. Helper function: get user's role
CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS TEXT AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- 8. Helper function: can user approve checks?
CREATE OR REPLACE FUNCTION public.can_approve_checks()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() 
    AND role IN ('admin', 'approver')
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- 9. Helper function: check if user created a specific check
CREATE OR REPLACE FUNCTION public.created_check(check_uuid UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.checks 
    WHERE id = check_uuid 
    AND created_by = auth.uid()
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- 10. Function to log audit trail
CREATE OR REPLACE FUNCTION public.log_check_audit(
  p_check_id UUID,
  p_action TEXT,
  p_changes JSONB DEFAULT NULL,
  p_metadata JSONB DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_audit_id UUID;
BEGIN
  INSERT INTO public.check_audit_log (check_id, user_id, action, changes, metadata)
  VALUES (p_check_id, auth.uid(), p_action, p_changes, p_metadata)
  RETURNING id INTO v_audit_id;
  
  RETURN v_audit_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 11. Function to check for duplicate checks within 7 days
CREATE OR REPLACE FUNCTION public.check_for_duplicates(
  p_account_id UUID,
  p_payee TEXT,
  p_amount TEXT
)
RETURNS TABLE(
  check_id UUID,
  check_number TEXT,
  created_at TIMESTAMPTZ,
  status TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    c.id,
    c.check_number,
    c.created_at,
    c.status
  FROM public.checks c
  WHERE c.account_id = p_account_id
    AND c.pay_to = p_payee
    AND c.amount = p_amount
    AND c.status IN ('pending', 'approved', 'printed')
    AND c.created_at > NOW() - INTERVAL '7 days'
  ORDER BY c.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 12. Trigger to automatically log check creation
CREATE OR REPLACE FUNCTION public.trigger_log_check_creation()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM public.log_check_audit(
    NEW.id,
    'created',
    to_jsonb(NEW),
    jsonb_build_object('ip', current_setting('request.headers', true)::json->>'x-forwarded-for')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_check_created ON public.checks;
CREATE TRIGGER on_check_created
  AFTER INSERT ON public.checks
  FOR EACH ROW EXECUTE FUNCTION public.trigger_log_check_creation();

-- 13. Trigger to log check updates
CREATE OR REPLACE FUNCTION public.trigger_log_check_update()
RETURNS TRIGGER AS $$
DECLARE
  v_changes JSONB;
  v_action TEXT;
BEGIN
  -- Detect what changed
  v_changes := jsonb_build_object(
    'old', to_jsonb(OLD),
    'new', to_jsonb(NEW)
  );
  
  -- Determine action based on status change
  IF OLD.status != NEW.status THEN
    CASE NEW.status
      WHEN 'approved' THEN v_action := 'approved';
      WHEN 'rejected' THEN v_action := 'rejected';
      WHEN 'printed' THEN v_action := 'printed';
      WHEN 'void' THEN v_action := 'voided';
      ELSE v_action := 'edited';
    END CASE;
  ELSE
    v_action := 'edited';
  END IF;
  
  PERFORM public.log_check_audit(NEW.id, v_action, v_changes, NULL);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_check_updated ON public.checks;
CREATE TRIGGER on_check_updated
  AFTER UPDATE ON public.checks
  FOR EACH ROW EXECUTE FUNCTION public.trigger_log_check_update();

-- 14. Trigger to add to duplicate tracking on creation
CREATE OR REPLACE FUNCTION public.trigger_track_duplicate()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.check_duplicates (account_id, payee, amount, check_id)
  VALUES (NEW.account_id, NEW.pay_to, NEW.amount, NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_check_created_track_duplicate ON public.checks;
CREATE TRIGGER on_check_created_track_duplicate
  AFTER INSERT ON public.checks
  FOR EACH ROW EXECUTE FUNCTION public.trigger_track_duplicate();

-- 15. Clean up old duplicate tracking entries (keep only 7 days)
CREATE OR REPLACE FUNCTION public.cleanup_old_duplicate_tracking()
RETURNS void AS $$
BEGIN
  DELETE FROM public.check_duplicates
  WHERE created_at < NOW() - INTERVAL '7 days';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 16. Update RLS policies for checks table
-- Drop old policies (including any from migration 003)
DROP POLICY IF EXISTS "Checks: select if admin or account access" ON public.checks;
DROP POLICY IF EXISTS "Checks: insert if admin or account access" ON public.checks;
DROP POLICY IF EXISTS "Checks: update/delete if admin or account access" ON public.checks;
DROP POLICY IF EXISTS "Checks: delete if admin or account access" ON public.checks;
DROP POLICY IF EXISTS "Checks: update if admin or account access" ON public.checks;

-- New policies with status-aware permissions
-- SELECT: Users can see checks for accounts they have access to
CREATE POLICY "Checks: select with account access"
  ON public.checks FOR SELECT
  USING (
    public.is_admin()
    OR EXISTS (
      SELECT 1 FROM public.account_users 
      WHERE user_id = auth.uid() 
      AND bank_account_id = checks.account_id
    )
  );

-- INSERT: Submitters create pending checks; Approvers can create approved/printed checks
CREATE POLICY "Checks: insert based on role"
  ON public.checks FOR INSERT
  WITH CHECK (
    -- Must have account access (unless admin)
    (
      public.is_admin()
      OR EXISTS (
        SELECT 1 FROM public.account_users 
        WHERE user_id = auth.uid() 
        AND bank_account_id = checks.account_id
      )
    )
    AND (
      -- Admins can create checks in any status
      public.is_admin()
      -- Approvers can create checks and mark as approved or printed (for their own checks)
      OR (
        EXISTS (
          SELECT 1 FROM public.profiles 
          WHERE id = auth.uid() 
          AND role = 'approver'
        )
        AND status IN ('pending', 'approved', 'printed')
      )
      -- Submitters can only create pending checks
      OR (
        EXISTS (
          SELECT 1 FROM public.profiles 
          WHERE id = auth.uid() 
          AND role = 'submitter'
        )
        AND status = 'pending'
      )
    )
  );

-- UPDATE: Complex rules based on status and role
CREATE POLICY "Checks: update based on status and role"
  ON public.checks FOR UPDATE
  USING (
    -- Must have account access
    (
      public.is_admin()
      OR EXISTS (
        SELECT 1 FROM public.account_users 
        WHERE user_id = auth.uid() 
        AND bank_account_id = checks.account_id
      )
    )
    AND (
      -- Admins can update anything
      public.is_admin()
      -- Submitters can edit their own pending checks
      OR (
        created_by = auth.uid()
        AND status = 'pending'
        AND public.get_user_role() IN ('submitter', 'approver')
      )
      -- Approvers can approve/reject/edit pending checks (but not their own unless can_self_approve)
      OR (
        public.can_approve_checks()
        AND status IN ('pending', 'approved')
        AND (
          created_by != auth.uid() 
          OR EXISTS (
            SELECT 1 FROM public.profiles 
            WHERE id = auth.uid() 
            AND can_self_approve = true
          )
        )
      )
    )
  )
  WITH CHECK (
    -- Enforce valid status transitions and prevent direct status manipulation
    (
      -- Can't change printed checks without admin override
      (OLD.status != 'printed' OR public.is_admin())
      -- Can't un-void checks
      AND (OLD.status != 'void' OR public.is_admin())
      -- Valid status transitions
      AND (
        (OLD.status = 'pending' AND NEW.status IN ('pending', 'approved', 'rejected'))
        OR (OLD.status = 'approved' AND NEW.status IN ('approved', 'printed', 'void'))
        OR (OLD.status = 'printed' AND NEW.status IN ('printed', 'void') AND public.is_admin())
        OR (OLD.status = 'rejected' AND NEW.status = 'rejected')
        OR (OLD.status = 'void' AND NEW.status = 'void')
      )
      -- Role-based status change rules
      AND (
        -- Admins can change any status
        public.is_admin()
        -- Approvers can:
        --   - Update their own checks to any valid status (for their workflow)
        --   - Approve/reject others' pending checks
        --   - Print approved checks
        OR (
          public.get_user_role() = 'approver'
          AND (
            -- Own checks: approver created it, can update freely within valid transitions
            created_by = auth.uid()
            -- Others' checks: can only approve/reject pending, or print approved
            OR (
              (OLD.status = 'pending' AND NEW.status IN ('approved', 'rejected'))
              OR (OLD.status = 'approved' AND NEW.status = 'printed')
            )
          )
        )
        -- Submitters can ONLY edit their own pending checks (status stays pending)
        OR (
          public.get_user_role() = 'submitter'
          AND created_by = auth.uid()
          AND OLD.status = 'pending'
          AND NEW.status = 'pending'
        )
      )
    )
  );

-- DELETE: Only admins can delete checks
CREATE POLICY "Checks: delete admin only"
  ON public.checks FOR DELETE
  USING (public.is_admin());

-- 17. RLS for audit log table
ALTER TABLE public.check_audit_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Audit log: select with check access"
  ON public.check_audit_log FOR SELECT
  USING (
    public.is_admin()
    OR EXISTS (
      SELECT 1 FROM public.checks c
      INNER JOIN public.account_users au ON au.bank_account_id = c.account_id
      WHERE c.id = check_audit_log.check_id
      AND au.user_id = auth.uid()
    )
  );

CREATE POLICY "Audit log: insert system only"
  ON public.check_audit_log FOR INSERT
  WITH CHECK (false);  -- Only triggers can insert

-- 18. RLS for duplicate tracking table
ALTER TABLE public.check_duplicates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Duplicates: select with account access"
  ON public.check_duplicates FOR SELECT
  USING (
    public.is_admin()
    OR EXISTS (
      SELECT 1 FROM public.account_users 
      WHERE user_id = auth.uid() 
      AND bank_account_id = check_duplicates.account_id
    )
  );

-- No insert/update/delete policies - only triggers can modify

-- 19. Create a view for pending approval queue
CREATE OR REPLACE VIEW public.approval_queue AS
SELECT 
  c.id,
  c.check_number,
  c.date,
  c.pay_to,
  c.amount,
  c.memo,
  c.expense_category,
  c.business_unit,
  c.account_id,
  ba.name as account_name,
  ba.bank_name,
  co.name as company_name,
  c.created_by,
  p.email as created_by_email,
  c.created_at,
  c.status,
  -- Check for duplicates
  (
    SELECT COUNT(*) FROM public.checks dup
    WHERE dup.account_id = c.account_id
    AND dup.pay_to = c.pay_to
    AND dup.amount = c.amount
    AND dup.id != c.id
    AND dup.status IN ('pending', 'approved', 'printed')
    AND dup.created_at > NOW() - INTERVAL '7 days'
  ) as duplicate_count
FROM public.checks c
INNER JOIN public.bank_accounts ba ON ba.id = c.account_id
INNER JOIN public.companies co ON co.id = ba.company_id
LEFT JOIN public.profiles p ON p.id = c.created_by
WHERE c.status = 'pending'
ORDER BY c.created_at ASC;

-- RLS for approval queue view
ALTER VIEW public.approval_queue SET (security_barrier = true);

-- Grant permissions on view
GRANT SELECT ON public.approval_queue TO authenticated;

-- 20. Backfill created_by for existing checks
-- For existing checks, try to determine who created them
-- If we can't determine, leave as NULL (treated as admin-created for permissions)
DO $$
BEGIN
  -- Leave existing checks with created_by = NULL
  -- This allows admins and approvers to manage them without restrictions
  RAISE NOTICE 'Existing checks: created_by left as NULL (treated as historical/admin-created)';
END $$;

-- 21. Create stored procedure for bulk approval
CREATE OR REPLACE FUNCTION public.bulk_approve_checks(
  p_check_ids UUID[]
)
RETURNS TABLE(
  check_id UUID,
  success BOOLEAN,
  error TEXT
) AS $$
DECLARE
  v_check_id UUID;
  v_can_approve BOOLEAN;
  v_created_by UUID;
  v_user_role TEXT;
BEGIN
  -- Check if user can approve
  v_can_approve := public.can_approve_checks();
  
  IF NOT v_can_approve THEN
    RETURN QUERY
    SELECT NULL::UUID, false, 'User does not have approval permissions'::TEXT;
    RETURN;
  END IF;
  
  -- Get user role
  SELECT role INTO v_user_role
  FROM public.profiles
  WHERE id = auth.uid();
  
  -- Process each check
  FOREACH v_check_id IN ARRAY p_check_ids
  LOOP
    BEGIN
      -- Get check creator
      SELECT created_by INTO v_created_by
      FROM public.checks
      WHERE id = v_check_id;
      
      -- Approvers can approve their own checks (no separation of duties restriction)
      -- Admins can approve anything
      -- This allows Karen to work normally
      
      -- Update check
      UPDATE public.checks
      SET 
        status = 'approved',
        approved_by = auth.uid(),
        approved_at = NOW()
      WHERE id = v_check_id
      AND status = 'pending';
      
      IF FOUND THEN
        -- Log approval with metadata
        PERFORM public.log_check_audit(
          v_check_id,
          'approved',
          NULL,
          jsonb_build_object(
            'self_approved', v_created_by = auth.uid(),
            'approver_role', v_user_role
          )
        );
        
        RETURN QUERY
        SELECT v_check_id, true, NULL::TEXT;
      ELSE
        RETURN QUERY
        SELECT v_check_id, false, 'Check not found or not in pending status'::TEXT;
      END IF;
      
    EXCEPTION WHEN OTHERS THEN
      RETURN QUERY
      SELECT v_check_id, false, SQLERRM::TEXT;
    END;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute on function
GRANT EXECUTE ON FUNCTION public.bulk_approve_checks TO authenticated;

-- 22. Secure new functions and tables from anon access
-- Revoke all access from anon/public on new tables
REVOKE ALL ON public.check_audit_log FROM anon;
REVOKE ALL ON public.check_audit_log FROM public;
GRANT SELECT ON public.check_audit_log TO authenticated;

REVOKE ALL ON public.check_duplicates FROM anon;
REVOKE ALL ON public.check_duplicates FROM public;
GRANT SELECT ON public.check_duplicates TO authenticated;

-- Set secure search_path on all SECURITY DEFINER functions
ALTER FUNCTION public.get_user_role() SET search_path = public, pg_temp;
ALTER FUNCTION public.can_approve_checks() SET search_path = public, pg_temp;
ALTER FUNCTION public.created_check(UUID) SET search_path = public, pg_temp;
ALTER FUNCTION public.log_check_audit(UUID, TEXT, JSONB, JSONB) SET search_path = public, pg_temp;
ALTER FUNCTION public.check_for_duplicates(UUID, TEXT, TEXT) SET search_path = public, pg_temp;
ALTER FUNCTION public.trigger_log_check_creation() SET search_path = public, pg_temp;
ALTER FUNCTION public.trigger_log_check_update() SET search_path = public, pg_temp;
ALTER FUNCTION public.trigger_track_duplicate() SET search_path = public, pg_temp;
ALTER FUNCTION public.cleanup_old_duplicate_tracking() SET search_path = public, pg_temp;
ALTER FUNCTION public.bulk_approve_checks(UUID[]) SET search_path = public, pg_temp;

-- Revoke EXECUTE from anon on all new functions
REVOKE EXECUTE ON FUNCTION public.get_user_role() FROM anon;
REVOKE EXECUTE ON FUNCTION public.get_user_role() FROM public;
GRANT EXECUTE ON FUNCTION public.get_user_role() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.can_approve_checks() FROM anon;
REVOKE EXECUTE ON FUNCTION public.can_approve_checks() FROM public;
GRANT EXECUTE ON FUNCTION public.can_approve_checks() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.created_check(UUID) FROM anon;
REVOKE EXECUTE ON FUNCTION public.created_check(UUID) FROM public;
GRANT EXECUTE ON FUNCTION public.created_check(UUID) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_check_audit(UUID, TEXT, JSONB, JSONB) FROM anon;
REVOKE EXECUTE ON FUNCTION public.log_check_audit(UUID, TEXT, JSONB, JSONB) FROM public;
GRANT EXECUTE ON FUNCTION public.log_check_audit(UUID, TEXT, JSONB, JSONB) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.check_for_duplicates(UUID, TEXT, TEXT) FROM anon;
REVOKE EXECUTE ON FUNCTION public.check_for_duplicates(UUID, TEXT, TEXT) FROM public;
GRANT EXECUTE ON FUNCTION public.check_for_duplicates(UUID, TEXT, TEXT) TO authenticated;

-- Trigger functions don't need explicit grants
REVOKE EXECUTE ON FUNCTION public.trigger_log_check_creation() FROM anon;
REVOKE EXECUTE ON FUNCTION public.trigger_log_check_creation() FROM public;

REVOKE EXECUTE ON FUNCTION public.trigger_log_check_update() FROM anon;
REVOKE EXECUTE ON FUNCTION public.trigger_log_check_update() FROM public;

REVOKE EXECUTE ON FUNCTION public.trigger_track_duplicate() FROM anon;
REVOKE EXECUTE ON FUNCTION public.trigger_track_duplicate() FROM public;

REVOKE EXECUTE ON FUNCTION public.cleanup_old_duplicate_tracking() FROM anon;
REVOKE EXECUTE ON FUNCTION public.cleanup_old_duplicate_tracking() FROM public;
GRANT EXECUTE ON FUNCTION public.cleanup_old_duplicate_tracking() TO authenticated;

-- bulk_approve_checks should only be callable by authenticated users
REVOKE EXECUTE ON FUNCTION public.bulk_approve_checks(UUID[]) FROM anon;
REVOKE EXECUTE ON FUNCTION public.bulk_approve_checks(UUID[]) FROM public;
GRANT EXECUTE ON FUNCTION public.bulk_approve_checks(UUID[]) TO authenticated;

-- 23. Comments for documentation
COMMENT ON TABLE public.check_audit_log IS 'Complete audit trail of all check operations';
COMMENT ON TABLE public.check_duplicates IS 'Recent checks for duplicate detection (7 day window)';
COMMENT ON COLUMN public.profiles.can_self_approve IS 'Admin override to allow user to approve their own checks (not used for approvers - they always can)';
COMMENT ON COLUMN public.checks.status IS 'Check lifecycle: pending -> approved -> printed (or rejected/void)';
COMMENT ON COLUMN public.checks.reprint_count IS 'Number of times check has been reprinted';
COMMENT ON VIEW public.approval_queue IS 'Pending checks awaiting approval with duplicate detection';
COMMENT ON FUNCTION public.bulk_approve_checks IS 'Approve multiple checks at once with separation of duties enforcement';
