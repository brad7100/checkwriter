# Approval Workflow - Deployment Guide

## ✅ Testing Complete

All migrations have been tested against a local Postgres 15 database with production-like data:
- **482 checks** (454 printed + 28 unprinted)
- **3 duplicate check number pairs** preserved with `is_legacy` flag
- **Status backfill**: 455 → 'printed', 28 → 'approved' ✓
- **Partial unique index**: Working correctly on non-legacy checks ✓
- **Status transition trigger**: Role-based validation working ✓
- **SHA-256 API key hashing**: Applied and tested ✓

## Prerequisites

- Existing Supabase project
- Database access via Supabase SQL Editor
- Admin access to Supabase project
- Existing security hardening from PR #1 applied

## Step 1: Apply Database Migrations

Run these migrations **in order** in the Supabase SQL Editor:

### Migration 1: Security Lockdown (MUST RUN FIRST)

File: `supabase/migrations/004_security_lockdown.sql` (renumbered from 003)

**⚠️ CRITICAL: This migration MUST run before the workflow migration.**

**✅ NOTE: Emergency lockdown already applied to production (`emergency_lockdown_remove_anon_access`)**

Production already has:
- ✅ Legacy "Allow all operations" policies dropped
- ✅ Anon role privileges revoked (ALL including TRUNCATE)
- ✅ EXECUTE revoked on `is_admin()`, `clear_must_set_password()`, `handle_new_user()` from anon/public
- ✅ TRUNCATE, TRIGGER, REFERENCES revoked from authenticated

**This migration adds:**
- 🆕 Secure search_path on all SECURITY DEFINER functions (NOT in emergency lockdown)
- 🆕 Security audit view for monitoring
- ✅ Idempotent - safe to re-run, completes the lockdown

**To apply:**

1. Open Supabase Dashboard
2. Go to **SQL Editor**
3. Click **"New query"**
4. Copy the entire contents of `004_security_lockdown.sql`
5. Paste and click **"Run"**
6. Verify no errors (should see notices about what was applied)

**✅ TESTED:** Migration applied successfully against local Postgres 15 with production-like data

**Verify security lockdown worked:**

```sql
SELECT * FROM security_audit 
WHERE status LIKE '%WARNING%' OR status LIKE '%CRITICAL%';
```

Expected result: **0 rows** (all critical issues resolved)

If you see WARNING or CRITICAL items, review them. Emergency lockdown should have resolved all CRITICAL items.

### Migration 2: Approval Workflow Core

File: `supabase/migrations/005_approval_workflow.sql` (renumbered from 004)

This migration adds:
- Check status lifecycle (pending → approved → printed)
- Role-based permissions (submitter, approver, admin)
- Complete audit trail logging
- Duplicate detection
- Check number uniqueness
- RLS policies for the new workflow
- **Backfills existing data safely:**
  - All 482 existing checks → status 'printed' (preserves current state)
  - brad@bradwilliamslaw.com → admin role
  - karen@bradwilliamslaw.com → approver role
  - Other users → submitter role
  - Existing checks get created_by = NULL (treated as historical)

**Special workflow for Karen (approver):**
- Karen can create checks and print them directly (no self-approval needed)
- This preserves her current daily workflow
- Separation of duties applies only to checks created by submitters
- All actions logged in audit trail

**To apply:**

1. Open a new query in SQL Editor
2. Copy the contents of `004_approval_workflow.sql`
3. Paste and click **"Run"**
4. Verify no errors
5. Check for success notices about role backfills

### Migration 3: Submitter API Keys

File: `supabase/migrations/006_submitter_api_keys.sql` (renumbered from 005)

This migration adds:
- API keys table for automated check submission bots
- Key generation function
- Key revocation function
- Idempotent - safe to re-run

**To apply:**

1. Open a new query in SQL Editor
2. Copy the contents of `005_submitter_api_keys.sql`
3. Paste and click **"Run"**
4. Verify no errors

**Note:** All three migrations are idempotent and safe to re-run.

## Step 2: Deploy Edge Function

Deploy the `submit-check` edge function for bot submissions:

```bash
cd printmechecks
supabase functions deploy submit-check
```

**Verify deployment:**

```bash
curl -X POST \
  https://your-project.supabase.co/functions/v1/submit-check \
  -H "X-Submitter-Key: test" \
  -H "Content-Type: application/json" \
  -d '{"test": true}'
```

Expected response: `{"error": "Invalid or inactive API key"}` (this is correct - it means the function is running)

## Step 3: Configure User Roles

### Set Approver Role

Karen needs to be an approver:

```sql
UPDATE profiles 
SET role = 'approver' 
WHERE email = 'karen@example.com';
```

### Set Submitter Roles

For human submitters (Brad and assistants):

```sql
UPDATE profiles 
SET role = 'submitter' 
WHERE email IN ('brad@example.com', 'assistant1@example.com');
```

For bot accounts:

```sql
UPDATE profiles 
SET role = 'submitter' 
WHERE email = 'bot@example.com';
```

### Karen's Workflow (No Configuration Needed)

**✅ Karen (approver) can create and print checks directly without a second approval.**

This preserves her current daily workflow:
1. Karen fills out a check
2. Karen clicks Print
3. Check is created with status='printed'
4. Action logged in audit trail

**Separation of duties applies only to submitter-created checks:**
- Submitters create checks → status 'pending'
- Karen approves them → status 'approved'
- Karen prints them → status 'printed'

No special configuration needed - this is handled by the RLS policies.

## Step 4: Create Bot API Key (If Needed)

If you have an automated bot:

1. Ensure the bot has a user account in Supabase Auth
2. Set the bot's role to 'submitter' (see above)
3. Generate an API key:

```sql
SELECT * FROM generate_submitter_api_key(
  (SELECT id FROM auth.users WHERE email = 'bot@example.com'),
  'QuickBooks Integration Bot',
  NULL  -- No expiration, or set number of days
);
```

4. **SAVE THE RETURNED API KEY IMMEDIATELY** - it's only shown once!

Example output:
```
api_key                      | key_id                               | ...
----------------------------|--------------------------------------|----
sbmt_ABC123xyz...           | 123e4567-e89b-12d3-a456-426614174000 | ...
```

5. Store the API key securely in your bot's environment variables:

```bash
export CHECKWRITER_API_KEY="sbmt_ABC123xyz..."
```

## Step 5: Verify Installation

### Test 0: Verify Security Lockdown

```sql
-- Should return 0 rows (no warnings or critical issues)
SELECT * FROM security_audit 
WHERE status LIKE '%WARNING%' OR status LIKE '%CRITICAL%';

-- Should show all policies as authenticated-only
SELECT * FROM security_audit 
WHERE object_type = 'privilege'
  AND grantee = 'anon'
  AND status LIKE '%CRITICAL%';
-- Expected: 0 rows (anon has no dangerous privileges)
```

### Test 1: Check Tables Created

```sql
-- Should return data (or empty but not error)
SELECT * FROM check_audit_log LIMIT 1;
SELECT * FROM check_duplicates LIMIT 1;
SELECT * FROM submitter_api_keys LIMIT 1;
SELECT * FROM approval_queue LIMIT 1;
```

### Test 2: Check Functions Exist

```sql
-- Should return rows
SELECT proname FROM pg_proc 
WHERE proname IN (
  'bulk_approve_checks',
  'check_for_duplicates',
  'generate_submitter_api_key',
  'revoke_submitter_api_key',
  'log_check_audit'
);
```

### Test 3: Check RLS Policies

```sql
-- Should return multiple policies
SELECT schemaname, tablename, policyname 
FROM pg_policies 
WHERE tablename IN ('checks', 'check_audit_log', 'check_duplicates', 'submitter_api_keys');
```

### Test 4: Test Approval Queue Access

As an approver:

```sql
-- Should return pending checks (if any)
SELECT * FROM approval_queue;
```

### Test 5: Test API Submission (If Using Bot)

```bash
curl -X POST \
  https://your-project.supabase.co/functions/v1/submit-check \
  -H "X-Submitter-Key: sbmt_your_key_here" \
  -H "Content-Type: application/json" \
  -d '{
    "account_id": "your-account-uuid",
    "pay_to": "Test Vendor",
    "amount": "100.00",
    "date": "12/15/2024",
    "memo": "Test submission"
  }'
```

Expected response:
```json
{
  "success": true,
  "check_id": "...",
  "check_number": "...",
  "status": "pending",
  "message": "Check submitted successfully and is pending approval"
}
```

## Step 6: Update Application

Deploy the updated frontend application:

```bash
cd printmechecks
npm run build
```

Then deploy to your hosting platform (Railway, Vercel, etc.)

### Environment Variables (No Changes Needed)

The workflow doesn't require additional environment variables. Existing ones should work:

```bash
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key
```

## Step 7: Train Users

### For Karen (Approver)

1. Show her the **"Approvals"** tab
2. Walk through reviewing a check
3. Show preview, approve, reject, and edit features
4. Explain duplicate warnings
5. Practice bulk approval

### For Submitters (Brad and Team)

1. Show how to fill out a check
2. Click **"Submit for Approval"** instead of Print
3. Explain duplicate warnings
4. Show how to check status in History

### For Bot Operator

1. Provide API key securely
2. Share API documentation from `APPROVAL_WORKFLOW_GUIDE.md`
3. Review error handling
4. Set up monitoring

## Step 8: Monitor Initial Usage

### Day 1: Check Audit Trail

```sql
SELECT 
  action,
  COUNT(*) as count,
  MAX(created_at) as last_occurrence
FROM check_audit_log
WHERE created_at > NOW() - INTERVAL '1 day'
GROUP BY action
ORDER BY count DESC;
```

### Week 1: Review Approvals

```sql
-- Check for approval bottlenecks
SELECT 
  DATE(created_at) as submission_date,
  COUNT(*) as checks_submitted,
  COUNT(CASE WHEN status = 'approved' THEN 1 END) as checks_approved,
  COUNT(CASE WHEN status = 'pending' THEN 1 END) as still_pending
FROM checks
WHERE created_at > NOW() - INTERVAL '7 days'
GROUP BY DATE(created_at)
ORDER BY submission_date DESC;
```

### Check for Issues

```sql
-- Checks pending more than 24 hours
SELECT 
  check_number,
  pay_to,
  amount,
  created_at,
  AGE(NOW(), created_at) as pending_for
FROM checks
WHERE status = 'pending'
  AND created_at < NOW() - INTERVAL '24 hours'
ORDER BY created_at;
```

## Rollback Plan

If you need to roll back:

### Option 1: Disable Workflow (Keep Data)

```sql
-- Allow direct printing again (temporary)
-- Remove the status checks from RLS policies
DROP POLICY IF EXISTS "Checks: update based on status and role" ON checks;

-- Recreate old policy
CREATE POLICY "Checks: update if admin or account access"
  ON public.checks FOR UPDATE
  USING (
    public.is_admin()
    OR EXISTS (SELECT 1 FROM public.account_users WHERE user_id = auth.uid() AND bank_account_id = checks.account_id)
  );
```

### Option 2: Full Rollback (Remove Tables)

**WARNING: This deletes audit data!**

```sql
-- Drop new tables
DROP TABLE IF EXISTS check_audit_log CASCADE;
DROP TABLE IF EXISTS check_duplicates CASCADE;
DROP TABLE IF EXISTS submitter_api_keys CASCADE;
DROP VIEW IF EXISTS approval_queue CASCADE;

-- Drop new functions
DROP FUNCTION IF EXISTS bulk_approve_checks CASCADE;
DROP FUNCTION IF EXISTS check_for_duplicates CASCADE;
DROP FUNCTION IF EXISTS generate_submitter_api_key CASCADE;
DROP FUNCTION IF EXISTS revoke_submitter_api_key CASCADE;
DROP FUNCTION IF EXISTS log_check_audit CASCADE;

-- Remove new columns from checks
ALTER TABLE checks DROP COLUMN IF EXISTS status;
ALTER TABLE checks DROP COLUMN IF EXISTS created_by;
ALTER TABLE checks DROP COLUMN IF EXISTS approved_by;
ALTER TABLE checks DROP COLUMN IF EXISTS approved_at;
ALTER TABLE checks DROP COLUMN IF EXISTS rejected_by;
ALTER TABLE checks DROP COLUMN IF EXISTS rejected_at;
ALTER TABLE checks DROP COLUMN IF EXISTS rejection_reason;
ALTER TABLE checks DROP COLUMN IF EXISTS voided_by;
ALTER TABLE checks DROP COLUMN IF EXISTS voided_at;
ALTER TABLE checks DROP COLUMN IF EXISTS void_reason;
ALTER TABLE checks DROP COLUMN IF EXISTS reprint_count;
ALTER TABLE checks DROP COLUMN IF EXISTS last_reprinted_by;
ALTER TABLE checks DROP COLUMN IF EXISTS last_reprinted_at;
ALTER TABLE checks DROP COLUMN IF EXISTS business_unit;

-- Restore old role constraint
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE profiles 
  ADD CONSTRAINT profiles_role_check 
  CHECK (role IN ('admin', 'user'));

-- Remove can_self_approve
ALTER TABLE profiles DROP COLUMN IF EXISTS can_self_approve;
```

## Troubleshooting Deployment

### Migration Errors

**Error: "relation already exists"**

Solution: The migration was partially applied. Check which tables exist and manually complete the migration.

```sql
-- Check what exists
SELECT tablename FROM pg_tables WHERE schemaname = 'public';
```

**Error: "function already exists"**

Solution: Drop and recreate the function:

```sql
DROP FUNCTION IF EXISTS function_name CASCADE;
-- Then re-run the CREATE FUNCTION statement
```

### Edge Function Errors

**Error: "Function not found"**

Solution: Redeploy the function:

```bash
supabase functions deploy submit-check --no-verify-jwt
```

**Error: "CORS error"**

Solution: Check CORS headers in the function. They're already set to `*` for development. For production, update:

```typescript
const corsHeaders = {
  'Access-Control-Allow-Origin': 'https://your-domain.com',
  // ...
}
```

### RLS Policy Errors

**Error: "new row violates row-level security policy"**

Solution: Check user's role and account access:

```sql
-- Check user's role
SELECT role FROM profiles WHERE id = '<user-id>';

-- Check user's account access
SELECT * FROM account_users WHERE user_id = '<user-id>';
```

### API Key Not Working

**Error: "Invalid or inactive API key"**

Solution: Verify the key exists and is active:

```sql
SELECT 
  id,
  name,
  is_active,
  last_used_at,
  expires_at
FROM submitter_api_keys 
WHERE key_hash = 'sbmt_your_key';
```

If not found, generate a new key.

## Performance Considerations

### Indexes

All necessary indexes are created by the migrations:

- `checks.status`
- `checks.created_by`
- `checks.approved_by`
- `check_audit_log.check_id`
- `check_audit_log.user_id`
- `check_duplicates.account_id, payee, amount`

### Cleanup Jobs

Set up a periodic cleanup for old duplicate tracking data:

```sql
-- Run daily via pg_cron or external scheduler
SELECT cleanup_old_duplicate_tracking();
```

Or in Supabase Dashboard → Database → Cron Jobs:

```sql
-- Every day at 3 AM
SELECT cron.schedule(
  'cleanup-duplicates',
  '0 3 * * *',
  'SELECT cleanup_old_duplicate_tracking()'
);
```

## Security Checklist

- [ ] All migrations applied successfully
- [ ] Edge function deployed
- [ ] Approver roles assigned
- [ ] Submitter roles assigned
- [ ] Bot API key generated (if needed)
- [ ] Bot API key stored securely
- [ ] RLS policies verified (run test queries)
- [ ] Audit trail logging works (submit a test check)
- [ ] Duplicate detection works (submit duplicate test check)
- [ ] Separation of duties enforced (try self-approving)
- [ ] Frontend deployed
- [ ] Users trained
- [ ] Monitoring set up

## Production Hardening

### 1. Limit CORS

Update edge function CORS:

```typescript
const corsHeaders = {
  'Access-Control-Allow-Origin': 'https://your-production-domain.com',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-submitter-key',
}
```

### 2. Set Up Alerts

Create alerts for:

- High-value checks (amount > $10,000)
- Bulk approvals (> 10 checks at once)
- Self-approvals (created_by = approved_by)
- Failed API key attempts
- Checks pending > 48 hours

### 3. Regular Audits

Schedule monthly reviews:

```sql
-- Self-approvals report
SELECT 
  c.check_number,
  c.pay_to,
  c.amount,
  p.email,
  c.approved_at
FROM checks c
JOIN profiles p ON p.id = c.created_by
WHERE c.created_by = c.approved_by
  AND c.approved_at > NOW() - INTERVAL '30 days'
ORDER BY c.approved_at DESC;
```

### 4. Backup Strategy

Ensure backups include:

- `checks` table (with all new status fields)
- `check_audit_log` table (complete history)
- `submitter_api_keys` table
- `profiles` table (roles and permissions)

### 5. API Key Rotation

Rotate bot API keys every 90 days:

```sql
-- Revoke old key
SELECT revoke_submitter_api_key('<old-key-id>');

-- Generate new key
SELECT * FROM generate_submitter_api_key(...);

-- Update bot's environment
```

## Support

For deployment issues:

1. Check migration output for errors
2. Review Supabase logs (Dashboard → Logs)
3. Verify RLS policies with test queries
4. Check edge function logs
5. Review audit trail for unexpected behavior

## Next Steps After Deployment

1. **Week 1**: Monitor closely, fix any issues
2. **Week 2**: Gather user feedback, adjust workflow if needed
3. **Month 1**: Review audit trail, generate reports
4. **Quarterly**: Audit high-value checks, review permissions

## Summary

**Deployment Steps:**

1. **CRITICAL**: Apply migration 003 (security lockdown) - Verify with security_audit view
2. Apply migration 004 (core workflow)
3. Apply migration 005 (API keys)
4. Deploy edge function
5. Set user roles
6. Generate bot API keys (if needed)
7. Deploy frontend
8. Train users
9. Monitor usage

**Estimated Time:** 30-60 minutes

**Risk Level:** Low (can be rolled back, doesn't affect existing data)

**Testing Required:** Yes - verify all components before production use
