# Check Approval Workflow - Quick Start

## What This PR Adds

A complete check approval workflow that requires checks to be submitted, approved by a second person, and then printed. Supports human submitters and automated bots.

## Key Benefits

✅ **Separation of Duties** - Submitters can't approve their own checks  
✅ **Complete Audit Trail** - Every operation logged with who and when  
✅ **Duplicate Protection** - Warns of similar checks in last 7 days  
✅ **Secure Bot Access** - API keys for automated submissions  
✅ **Simple UI** - Easy for non-technical approvers  

## How It Works

### For Karen (Approver)
1. Go to **"Approvals"** tab (badge shows count)
2. Review pending checks
3. Click preview to see what it will look like
4. Approve, reject, or edit
5. Print approved checks

### For Brad (Submitter)
1. Fill out check as usual
2. Click **"Submit for Approval"** instead of Print
3. Karen approves it
4. Karen prints it

### For Bots
1. POST to edge function with check data
2. Check enters pending status
3. Karen approves it
4. Karen prints it

## Installation (30-60 minutes)

### 1. Apply Database Migrations
In Supabase SQL Editor, run these **in order**:

**⚠️ CRITICAL FIRST STEP:**
- `supabase/migrations/003_security_lockdown.sql` - **MUST RUN FIRST**
  - Fixes critical security vulnerabilities in existing database
  - Drops allow-all policies
  - Revokes anon over-privileges
  - Verify with: `SELECT * FROM security_audit WHERE status LIKE '%CRITICAL%';` (should return 0 rows)

Then:
- `supabase/migrations/004_approval_workflow.sql`
- `supabase/migrations/005_submitter_api_keys.sql`

### 2. Set User Roles
```sql
-- Make Karen an approver
UPDATE profiles SET role = 'approver' WHERE email = 'karen@example.com';

-- Make Brad a submitter
UPDATE profiles SET role = 'submitter' WHERE email = 'brad@example.com';
```

### 3. Deploy Edge Function (If Using Bots)
```bash
cd printmechecks
supabase functions deploy submit-check
```

### 4. Generate Bot API Key (If Using Bots)
```sql
SELECT * FROM generate_submitter_api_key(
  (SELECT id FROM auth.users WHERE email = 'bot@example.com'),
  'My Bot Name',
  NULL
);
```
**Save the key! It's only shown once.**

### 5. Deploy Frontend
```bash
npm run build
# Deploy to your hosting platform
```

### 6. Test It
1. Log in as Brad
2. Create and submit a check
3. Log in as Karen
4. Approve the check from Approvals tab
5. Print it

## Documentation

- **`TESTING_DISCLOSURE.md`** - **READ THIS FIRST** - Testing methodology and required validation
- **`APPROVAL_WORKFLOW_GUIDE.md`** - Complete user guide for Karen, submitters, and bots
- **`DEPLOYMENT_GUIDE.md`** - Detailed deployment steps and troubleshooting
- **This file** - Quick reference

## Important Notes

⚠️ **This code has NOT been tested against a live Supabase instance.**

See `TESTING_DISCLOSURE.md` for:
- What testing was actually performed (code review only)
- Critical security issues found and fixed
- Required testing before production
- Honest assessment of readiness

**DO NOT deploy to production without testing on a test Supabase instance first.**

## Security

### Critical Fixes Applied
Migration 003 fixes vulnerabilities found in production audit:
- ❌ **REMOVED**: Allow-all policies that bypassed security
- ❌ **REMOVED**: Anon role TRUNCATE and write privileges
- ✅ **SECURED**: All SECURITY DEFINER functions
- ✅ **ENFORCED**: Authenticated-only access

### Workflow Security
All permissions enforced at database level with RLS:
- Submitters can only create pending checks
- Approvers can approve/reject/edit checks
- No one can approve their own checks (unless admin override)
- Status changes require proper roles (can't bypass to 'approved')
- All operations logged in audit trail

## Support

See full documentation files for:
- Detailed installation steps
- API examples (Python, cURL)
- Troubleshooting
- Audit queries
- Rollback instructions

## Questions?

Review the deployment guide or contact your system administrator.

---

**PR**: https://github.com/brad7100/checkwriter/pull/2  
**Status**: Ready for review and deployment
