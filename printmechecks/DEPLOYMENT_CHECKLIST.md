# Production Deployment Checklist for PR #2

## Pre-Deployment Status

✅ **Emergency lockdown already applied to production:**
- Legacy "Allow all operations" policies dropped
- Anon role privileges revoked
- EXECUTE revoked on critical functions from anon/public
- TRUNCATE/TRIGGER/REFERENCES revoked from authenticated

✅ **Production data inventory:**
- 482 existing checks (will become status='printed')
- 9 bank accounts (unchanged)
- 4 users (will get appropriate roles)

✅ **Karen's workflow preserved:**
- Can create and print checks directly
- No self-approval needed
- Current daily workflow unchanged

## Deployment Steps

### Step 1: Apply Database Migrations (IN ORDER)

**⚠️ CRITICAL: Run in this exact order**

#### Migration 1: `003_security_lockdown.sql`
```sql
-- Copy and paste entire file in Supabase SQL Editor
-- Then run
```

**What it does:**
- Completes emergency lockdown with search_path fixes
- Creates security_audit view
- Idempotent - safe to re-run

**Verify:**
```sql
SELECT * FROM security_audit WHERE status LIKE '%CRITICAL%';
-- Expected: 0 rows
```

#### Migration 2: `004_approval_workflow.sql`
```sql
-- Copy and paste entire file in Supabase SQL Editor
-- Then run
```

**What it does:**
- Adds status column to checks (default='printed' for existing)
- Backfills all 482 existing checks to status='printed'
- Sets brad@bradwilliamslaw.com as admin
- Sets karen@bradwilliamslaw.com as approver
- Sets other users as submitters
- Creates audit trail and duplicate detection
- Sets up RLS policies

**Verify:**
```sql
-- Check user roles
SELECT email, role FROM profiles ORDER BY role;

-- Check existing checks got status
SELECT status, COUNT(*) FROM checks GROUP BY status;
-- Expected: 482 checks with status='printed'
```

#### Migration 3: `005_submitter_api_keys.sql`
```sql
-- Copy and paste entire file in Supabase SQL Editor
-- Then run
```

**What it does:**
- Creates API keys table for bots
- Adds key generation functions
- Idempotent - safe to re-run

**Verify:**
```sql
SELECT COUNT(*) FROM submitter_api_keys;
-- Expected: 0 (no keys yet)
```

### Step 2: Deploy Edge Function (Optional - Only If Using Bots)

```bash
cd printmechecks
supabase functions deploy submit-check
```

**Verify:**
```bash
curl -X POST \
  https://cffhvhgvaidwofyceoju.supabase.co/functions/v1/submit-check \
  -H "X-Submitter-Key: test" \
  -d '{}'
```
Expected: Error about invalid key (means function is running)

### Step 3: Deploy Frontend

```bash
cd printmechecks
npm install  # If dependencies changed
npm run build
# Deploy to Railway or your hosting platform
```

**No new environment variables needed**
- Uses existing VITE_SUPABASE_URL
- Uses existing VITE_SUPABASE_ANON_KEY

### Step 4: Test Karen's Workflow

1. Log in as karen@bradwilliamslaw.com
2. Go to Check Writer
3. Fill out a check
4. Click "Print" (should work directly)
5. Verify check created with status='printed'
6. Check audit log shows the action

**Test SQL:**
```sql
SELECT 
  check_number,
  pay_to,
  status,
  created_by,
  created_at
FROM checks
WHERE created_at > NOW() - INTERVAL '1 hour'
ORDER BY created_at DESC
LIMIT 5;
```

### Step 5: Test Submitter Workflow

1. Log in as a submitter user
2. Go to Check Writer
3. Fill out a check
4. Should see "Submit for Approval" button
5. Click it
6. Verify check created with status='pending'
7. Log in as Karen
8. Go to Approvals tab
9. See the pending check
10. Approve and print it

### Step 6: Verify Audit Trail

```sql
SELECT 
  action,
  COUNT(*) as count
FROM check_audit_log
WHERE created_at > NOW() - INTERVAL '1 hour'
GROUP BY action;
```

Expected actions: created, printed, approved (depending on tests)

### Step 7: Verify Existing Data Intact

```sql
-- All existing checks should be status='printed'
SELECT COUNT(*) FROM checks WHERE status = 'printed';
-- Expected: 482 (or more if new checks created)

-- No data loss
SELECT COUNT(*) FROM checks;
-- Expected: 482 + any new checks

-- Bank accounts unchanged
SELECT COUNT(*) FROM bank_accounts;
-- Expected: 9

-- Users have roles
SELECT email, role FROM profiles WHERE role IS NOT NULL;
-- Expected: All 4 users have roles
```

## Post-Deployment Verification

### Security Checks

```sql
-- No critical security issues
SELECT * FROM security_audit WHERE status LIKE '%CRITICAL%';
-- Expected: 0 rows

-- Anon has no table access
SELECT * FROM security_audit 
WHERE object_type = 'privilege' 
  AND grantee = 'anon' 
  AND status LIKE '%CRITICAL%';
-- Expected: 0 rows

-- Functions are secured
SELECT * FROM security_audit 
WHERE object_type = 'function' 
  AND status LIKE '%CRITICAL%';
-- Expected: 0 rows
```

### Functional Checks

```sql
-- Karen can still print checks (approver workflow)
-- Test by creating a check as Karen

-- Submitters see approval workflow
-- Test by creating a check as a submitter

-- Existing checks remain accessible
SELECT * FROM checks WHERE id = '<existing-check-id>';
-- Should return data

-- Audit trail is logging
SELECT COUNT(*) FROM check_audit_log;
-- Should increase with each action
```

## Rollback Plan (If Needed)

If something breaks:

### Quick Rollback (Keep Data, Disable Workflow)

```sql
-- Allow everyone to print directly (temporary)
DROP POLICY IF EXISTS "Checks: update based on status and role" ON checks;
DROP POLICY IF EXISTS "Checks: insert based on role" ON checks;

-- Restore simple policies
CREATE POLICY "Checks: update if account access"
  ON checks FOR UPDATE
  USING (
    public.is_admin()
    OR EXISTS (SELECT 1 FROM account_users WHERE user_id = auth.uid() AND bank_account_id = checks.account_id)
  );

CREATE POLICY "Checks: insert if account access"
  ON checks FOR INSERT
  WITH CHECK (
    public.is_admin()
    OR EXISTS (SELECT 1 FROM account_users WHERE user_id = auth.uid() AND bank_account_id = checks.account_id)
  );
```

### Full Rollback (Advanced - Contact DBA)

Do not attempt unless absolutely necessary - data may be lost.

## Success Criteria

✅ All migrations applied without errors
✅ Security audit shows 0 CRITICAL items
✅ Karen can create and print checks directly
✅ Submitters see "Submit for Approval" button
✅ Karen can see and approve pending checks
✅ Existing 482 checks remain accessible
✅ All 9 bank accounts still work
✅ All 4 users have appropriate roles
✅ Audit trail is logging actions
✅ No errors in application logs

## Monitoring

After deployment, monitor for 24 hours:

1. **Check creation rate** - should match normal usage
2. **Audit log entries** - should see created, printed, approved actions
3. **User complaints** - Karen should report no workflow changes
4. **Error logs** - watch for RLS policy rejections
5. **Performance** - check query times haven't degraded

## Support Contacts

If issues arise:
- Check `DEPLOYMENT_GUIDE.md` for troubleshooting
- Check `TESTING_DISCLOSURE.md` for known limitations
- Review `APPROVAL_WORKFLOW_GUIDE.md` for user workflows

## Notes

- All migrations are idempotent - safe to re-run
- Emergency lockdown already applied - migrations complete it
- Karen's workflow unchanged - she prints directly
- Submitters get approval workflow - new functionality
- Existing data preserved - 482 checks safe
- No new environment variables needed

## Final Check Before Going Live

- [ ] Emergency lockdown status verified
- [ ] All 3 migrations run successfully
- [ ] Security audit shows 0 CRITICAL
- [ ] User roles verified (brad=admin, karen=approver)
- [ ] Existing checks status backfilled to 'printed'
- [ ] Frontend deployed with no new env vars
- [ ] Karen's workflow tested and working
- [ ] Submitter workflow tested and working
- [ ] Approval queue tested and working
- [ ] Audit trail confirmed logging
- [ ] Existing data verified intact (482 checks, 9 accounts)

## Deployment Complete!

Once all checks pass, PR #2 is successfully deployed to production.
