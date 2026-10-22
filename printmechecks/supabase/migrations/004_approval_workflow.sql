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
ALTER TABLE public.profiles 
  ADD COLUMN IF NOT EXISTS can_self_approve BOOLEAN DEFAULT false;

-- 2. Add check status and workflow fields to checks table
ALTER TABLE public.checks 
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'pending' 
    CHECK (status IN ('pending', 'approved', 'rejected', 'printed', 'void'));

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
-- Drop old policies
DROP POLICY IF EXISTS "Checks: select if admin or account access" ON public.checks;
DROP POLICY IF EXISTS "Checks: insert if admin or account access" ON public.checks;
DROP POLICY IF EXISTS "Checks: update/delete if admin or account access" ON public.checks;
DROP POLICY IF EXISTS "Checks: delete if admin or account access" ON public.checks;

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

-- INSERT: Submitters and admins can create pending checks
CREATE POLICY "Checks: insert as pending"
  ON public.checks FOR INSERT
  WITH CHECK (
    status = 'pending'
    AND (
      public.is_admin()
      OR EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE id = auth.uid() 
        AND role IN ('submitter', 'approver', 'admin')
      )
    )
    AND (
      public.is_admin()
      OR EXISTS (
        SELECT 1 FROM public.account_users 
        WHERE user_id = auth.uid() 
        AND bank_account_id = checks.account_id
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
    -- Enforce valid status transitions
    (
      -- Can't change printed checks without admin override
      (OLD.status != 'printed' OR public.is_admin())
      -- Can't un-void checks
      AND (OLD.status != 'void' OR public.is_admin())
      -- Pending can go to approved, rejected, or stay pending
      AND (
        (OLD.status = 'pending' AND NEW.status IN ('pending', 'approved', 'rejected'))
        OR (OLD.status = 'approved' AND NEW.status IN ('approved', 'printed', 'void'))
        OR (OLD.status = 'printed' AND NEW.status IN ('printed', 'void') AND public.is_admin())
        OR (OLD.status = 'rejected' AND NEW.status = 'rejected')
        OR (OLD.status = 'void' AND NEW.status = 'void')
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
-- Set to null initially - admin should assign if needed
UPDATE public.checks 
SET created_by = NULL 
WHERE created_by IS NULL;

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
  v_can_self_approve BOOLEAN;
BEGIN
  -- Check if user can approve
  v_can_approve := public.can_approve_checks();
  
  IF NOT v_can_approve THEN
    RETURN QUERY
    SELECT NULL::UUID, false, 'User does not have approval permissions'::TEXT;
    RETURN;
  END IF;
  
  -- Check self-approve permission
  SELECT can_self_approve INTO v_can_self_approve
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
      
      -- Verify separation of duties
      IF v_created_by = auth.uid() AND NOT v_can_self_approve THEN
        RETURN QUERY
        SELECT v_check_id, false, 'Cannot approve own check without admin override'::TEXT;
        CONTINUE;
      END IF;
      
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
            'admin_override', v_can_self_approve
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

-- 22. Comments for documentation
COMMENT ON TABLE public.check_audit_log IS 'Complete audit trail of all check operations';
COMMENT ON TABLE public.check_duplicates IS 'Recent checks for duplicate detection (7 day window)';
COMMENT ON COLUMN public.profiles.can_self_approve IS 'Admin override to allow user to approve their own checks';
COMMENT ON COLUMN public.checks.status IS 'Check lifecycle: pending -> approved -> printed (or rejected/void)';
COMMENT ON COLUMN public.checks.reprint_count IS 'Number of times check has been reprinted';
COMMENT ON VIEW public.approval_queue IS 'Pending checks awaiting approval with duplicate detection';
COMMENT ON FUNCTION public.bulk_approve_checks IS 'Approve multiple checks at once with separation of duties enforcement';
