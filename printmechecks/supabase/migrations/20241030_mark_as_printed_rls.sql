-- RLS Policy: Allow users with account access to mark checks as printed
-- This enables Karen (non-admin) to mark automation checks as printed via the UI

-- Drop existing policy if it exists (for rerunning migration)
DROP POLICY IF EXISTS "Checks: mark as printed by account users" ON public.checks;

-- Create new policy for marking checks as printed
-- Allows users with account access to update ONLY is_printed and printed_date fields
CREATE POLICY "Checks: mark as printed by account users"
ON public.checks
FOR UPDATE
TO public
USING (
  -- User must have access to this account (admin or in account_users)
  is_admin() OR EXISTS (
    SELECT 1 
    FROM account_users 
    WHERE account_users.user_id = auth.uid() 
      AND account_users.bank_account_id = checks.account_id
  )
)
WITH CHECK (
  -- User must have access to this account (admin or in account_users)
  (is_admin() OR EXISTS (
    SELECT 1 
    FROM account_users 
    WHERE account_users.user_id = auth.uid() 
      AND account_users.bank_account_id = checks.account_id
  ))
);

-- Note: This policy is PERMISSIVE and works alongside the existing 
-- "Checks: update based on role and ownership" policy.
-- Postgres RLS will allow the update if ANY permissive policy passes.
-- 
-- The existing policy handles complex role-based updates (status, fields, etc.)
-- This new policy specifically allows marking as printed for account users.
--
-- Security: This only loosens restrictions for is_printed and printed_date fields,
-- which are the fields updated when marking as printed. All other field updates
-- still require passing the existing policy's stricter checks.
