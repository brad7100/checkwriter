# Check Approval Workflow - User Guide

## Overview

The check approval workflow adds a multi-step approval process to ensure financial controls and separation of duties. Checks must be submitted, approved by an authorized person, and then printed.

## For Approvers (Karen)

### Accessing the Approval Queue

1. **Log in** to the application
2. Click on the **"Approvals"** tab in the navigation bar
3. You'll see a badge showing how many checks are waiting for approval

### Reviewing Pending Checks

The approval queue shows all checks waiting for your approval:

- **Check details**: Check number, payee, amount, date, submitter
- **Duplicate warnings**: Checks with similar amounts to the same payee in the last 7 days are highlighted in yellow
- **Account and company**: Which bank account the check is drawn on

### Approving Checks

#### Single Check Approval

1. Click the **green checkmark button** or **"Preview"** button on a check
2. In the preview modal, you'll see:
   - A visual preview of what the printed check will look like
   - Complete check details (payee, amount, memo, category, etc.)
   - Duplicate warnings if applicable
3. Click **"Approve"** to approve the check

#### Bulk Approval

1. Check the boxes next to multiple checks
2. Click **"Approve Selected"** at the top
3. All selected checks will be approved at once

#### Approve and Print

1. Select one or more checks
2. Click **"Approve & Print"**
3. Checks are approved and you can navigate to print them immediately

### Editing Checks

If a check needs corrections before approval:

1. Click the **pencil icon** on the check
2. Make necessary changes (payee, amount, date, memo, category)
3. Click **"Save Changes"**
4. The updated check remains pending for approval

### Rejecting Checks

If a check shouldn't be paid:

1. Click the **red X button** on the check
2. Enter a **reason for rejection** (required)
3. Click **"Reject Check"**
4. The submitter will be notified and the check moves to rejected status

### Duplicate Warnings

- Checks with **yellow highlighting** indicate possible duplicates
- The system checks for same payee + same amount within 7 days
- Review carefully to prevent double-payments
- You can still approve if the duplicate is intentional

## For Submitters (Brad and Assistants)

### Creating a Check for Approval

1. **Log in** to the application
2. Go to the **"Check Writer"** tab
3. Fill out all check fields:
   - Select **Company** and **Bank Account**
   - Enter **Payee** name
   - Enter **Amount**
   - Enter **Date** (defaults to today)
   - Optional: **Memo**, **Check Number**, **Expense Category**, **Business Unit**
4. Click **"Submit for Approval"**

### Duplicate Warnings

- If a similar check exists (same payee and amount within 7 days), you'll get a warning
- Review the warning and choose to proceed or cancel

### Checking Status

- After submission, the check enters "pending" status
- An approver must review and approve it before it can be printed
- You can see check status in the History view

## For Automated Bots

### API Key Setup (Admin Only)

1. An admin must create an API key for the bot:

```sql
-- In Supabase SQL Editor
SELECT * FROM generate_submitter_api_key(
  '<bot-user-uuid>',  -- The UUID of the bot's user account
  'My Bot Name',       -- A descriptive name
  NULL                 -- NULL = no expiration, or number of days
);
```

2. **Save the returned API key immediately** - it's only shown once!

### Submitting Checks via API

**Endpoint**: `https://your-project.supabase.co/functions/v1/submit-check`

**Headers**:
```
X-Submitter-Key: sbmt_<your-api-key>
Content-Type: application/json
```

**Request Body** (JSON):
```json
{
  "account_id": "<bank-account-uuid>",
  "pay_to": "Vendor Name",
  "amount": "1250.00",
  "date": "12/15/2024",
  "memo": "Invoice #12345",
  "expense_category": "Office Supplies",
  "business_unit": "Marketing",
  "check_number": "1001"
}
```

**Required Fields**:
- `account_id` - UUID of the bank account
- `pay_to` - Payee name
- `amount` - Amount as string (e.g., "1250.00")
- `date` - Check date

**Optional Fields**:
- `memo` - Memo line text
- `check_number` - Specific check number (auto-generated if omitted)
- `expense_category` - Category for accounting
- `business_unit` - Business unit or department

**Response (Success)**:
```json
{
  "success": true,
  "check_id": "<uuid>",
  "check_number": "1001",
  "status": "pending",
  "duplicate_warning": false,
  "message": "Check submitted successfully and is pending approval"
}
```

**Response (Duplicate Warning)**:
```json
{
  "success": true,
  "check_id": "<uuid>",
  "check_number": "1001",
  "status": "pending",
  "duplicate_warning": true,
  "duplicates": [
    {
      "check_id": "<uuid>",
      "check_number": "998",
      "created_at": "2024-12-10T10:30:00Z",
      "status": "printed"
    }
  ],
  "message": "Check submitted successfully but similar checks were found in the last 7 days"
}
```

**Response (Error)**:
```json
{
  "error": "Description of what went wrong"
}
```

**cURL Example**:
```bash
curl -X POST \
  https://your-project.supabase.co/functions/v1/submit-check \
  -H "X-Submitter-Key: sbmt_your_api_key_here" \
  -H "Content-Type: application/json" \
  -d '{
    "account_id": "123e4567-e89b-12d3-a456-426614174000",
    "pay_to": "Office Depot",
    "amount": "523.45",
    "date": "12/15/2024",
    "memo": "Office supplies",
    "expense_category": "Supplies"
  }'
```

**Python Example**:
```python
import requests

API_KEY = "sbmt_your_api_key_here"
SUPABASE_URL = "https://your-project.supabase.co"

def submit_check(account_id, payee, amount, date, memo=None, category=None):
    headers = {
        "X-Submitter-Key": API_KEY,
        "Content-Type": "application/json"
    }
    
    payload = {
        "account_id": account_id,
        "pay_to": payee,
        "amount": str(amount),
        "date": date,
    }
    
    if memo:
        payload["memo"] = memo
    if category:
        payload["expense_category"] = category
    
    response = requests.post(
        f"{SUPABASE_URL}/functions/v1/submit-check",
        headers=headers,
        json=payload
    )
    
    return response.json()

# Example usage
result = submit_check(
    account_id="123e4567-e89b-12d3-a456-426614174000",
    payee="Acme Corp",
    amount=1500.00,
    date="12/15/2024",
    memo="Monthly service",
    category="Services"
)
print(result)
```

## For Administrators

### Managing Roles

Users can have one of four roles:

- **admin** - Full access to everything
- **approver** - Can approve, reject, edit, and print checks
- **submitter** - Can create and submit checks for approval
- **user** - Basic access (legacy role)

**To set a user as an approver:**

```sql
-- In Supabase SQL Editor
UPDATE profiles 
SET role = 'approver' 
WHERE email = 'karen@example.com';
```

**To set a user as a submitter:**

```sql
UPDATE profiles 
SET role = 'submitter' 
WHERE email = 'bot@example.com';
```

### Self-Approval Override

By default, users cannot approve their own checks. For admins who need to submit and approve:

```sql
UPDATE profiles 
SET can_self_approve = true 
WHERE email = 'admin@example.com';
```

**Note**: Self-approvals are logged in the audit trail.

### Creating Bot API Keys

```sql
-- First, ensure the bot has a submitter account
-- Then generate an API key
SELECT * FROM generate_submitter_api_key(
  (SELECT id FROM auth.users WHERE email = 'bot@example.com'),
  'QuickBooks Integration Bot',
  NULL  -- No expiration
);
```

**Save the returned key immediately!**

### Revoking API Keys

```sql
SELECT revoke_submitter_api_key('<key-uuid>');
```

Or deactivate in the database:

```sql
UPDATE submitter_api_keys 
SET is_active = false 
WHERE id = '<key-uuid>';
```

### Viewing Audit Trail

All check operations are logged:

```sql
SELECT 
  cal.*,
  p.email as user_email,
  c.check_number,
  c.pay_to,
  c.amount
FROM check_audit_log cal
LEFT JOIN profiles p ON p.id = cal.user_id
LEFT JOIN checks c ON c.id = cal.check_id
ORDER BY cal.created_at DESC
LIMIT 100;
```

### Checking for Unusual Activity

```sql
-- Check for self-approvals
SELECT 
  c.check_number,
  c.pay_to,
  c.amount,
  p.email,
  c.created_at,
  c.approved_at
FROM checks c
JOIN profiles p ON p.id = c.created_by
WHERE c.created_by = c.approved_by
  AND c.status = 'approved'
ORDER BY c.approved_at DESC;

-- Check for bulk approvals by one user
SELECT 
  approved_by,
  p.email,
  DATE(approved_at) as approval_date,
  COUNT(*) as checks_approved,
  SUM(CAST(amount AS NUMERIC)) as total_amount
FROM checks c
LEFT JOIN profiles p ON p.id = c.approved_by
WHERE approved_at IS NOT NULL
GROUP BY approved_by, p.email, DATE(approved_at)
HAVING COUNT(*) > 10
ORDER BY approval_date DESC;
```

## Status Lifecycle

Checks follow this lifecycle:

1. **pending** - Submitted and waiting for approval
2. **approved** - Approved and ready to print
3. **printed** - Successfully printed
4. **rejected** - Rejected by approver (with reason)
5. **void** - Voided by admin

### Status Transitions

- `pending` → `approved` (by approver)
- `pending` → `rejected` (by approver)
- `approved` → `printed` (when printed)
- `approved` → `void` (by admin)
- `printed` → `void` (by admin)

### Reprint Controls

- Once printed, checks cannot be re-printed by regular approvers
- Admins can reprint checks (logged with reprint count)
- Each reprint increments `reprint_count` and logs who reprinted it

## Security Features

### Separation of Duties

- Submitters cannot approve their own checks
- Exception: Admins with `can_self_approve = true` (logged)
- Enforced at database level with RLS policies

### Audit Trail

Every action is logged:
- Who created the check
- Who edited it (and what changed)
- Who approved/rejected it
- Who printed it
- Who reprinted it (if applicable)

### Duplicate Protection

- Checks with same payee + amount in last 7 days trigger warnings
- Helps prevent accidental double-payments
- Can still approve if legitimate (e.g., recurring payments)

### API Key Security

- API keys are scoped to specific user accounts
- Keys can be revoked immediately
- Key usage is tracked (`last_used_at`)
- Keys can have expiration dates

### Check Number Uniqueness

- Check numbers must be unique per bank account
- Enforced at database level
- Voided checks release their number

## Troubleshooting

### "Only approved checks can be printed"

**Solution**: The check must be submitted for approval first. Click "Submit for Approval" then have an approver approve it.

### "Cannot approve own check without admin override"

**Solution**: Have a different user with approver role approve the check. Or, if you're an admin, update your profile: `UPDATE profiles SET can_self_approve = true WHERE id = '<your-id>';`

### "This check has already been printed"

**Solution**: Reprinting requires admin privileges. Contact your administrator.

### "Invalid or inactive API key"

**Solutions**:
- Verify the API key is correct (starts with `sbmt_`)
- Check if the key has been revoked: `SELECT * FROM submitter_api_keys WHERE key_hash = 'your_key';`
- Generate a new key if needed

### "User must have submitter, approver, or admin role"

**Solution**: Update the user's role in the profiles table:
```sql
UPDATE profiles SET role = 'submitter' WHERE email = 'user@example.com';
```

### Duplicate warning not appearing

**Solution**: The system only checks the last 7 days. Older duplicates won't trigger warnings. Adjust the time window in the migration if needed.

## Best Practices

### For Approvers

1. Always review the check preview before approving
2. Pay attention to duplicate warnings
3. Verify payee names match your vendor list
4. Check amounts against invoices or purchase orders
5. Use rejection with clear reasons for feedback

### For Submitters

1. Fill out all fields completely (especially memo and category)
2. Double-check amounts before submitting
3. Review duplicate warnings carefully
4. Include invoice numbers in memo field

### For Admins

1. Regularly review the audit trail
2. Monitor self-approvals
3. Rotate API keys periodically
4. Limit `can_self_approve` to only necessary users
5. Review high-value check approvals

### For Bot Integrations

1. Store API keys securely (environment variables, not in code)
2. Handle duplicate warnings gracefully
3. Log all API responses for troubleshooting
4. Implement retry logic for network errors
5. Monitor API key expiration dates

## Configuration

All configuration is in the database migrations. No environment variables needed for the workflow itself.

### Adjusting Duplicate Detection Window

Default is 7 days. To change:

```sql
-- In the check_for_duplicates function
-- Change: c.created_at > NOW() - INTERVAL '7 days'
-- To your desired window
ALTER FUNCTION check_for_duplicates ...
```

### Adjusting Check Number Starting Point

Default is 1000. Change in the migration or per-account in the app.

## Support

For issues or questions:

1. Check this guide first
2. Review the audit trail for what happened
3. Check Supabase logs for errors
4. Contact your system administrator

## Summary

**Karen's workflow:**
1. Go to Approvals tab
2. Review pending checks
3. Preview → Approve or Reject
4. Print approved checks

**Submitter's workflow:**
1. Fill out check in Check Writer
2. Click "Submit for Approval"
3. Wait for approval
4. Karen prints it

**Bot's workflow:**
1. Get API key from admin
2. POST to `/functions/v1/submit-check`
3. Check response for success/duplicates
4. Wait for human approval
5. Human prints the approved check
