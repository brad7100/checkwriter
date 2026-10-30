# CheckPrint Navigation Redesign - Deployment Notes

## Overview

This redesign replaces dropdown-based company/account selection with a modern step-by-step flow using visual card-based pickers.

## What Changed

### 1. Navigation Flow
- **Before**: Dropdowns in the check writer for company and account selection
- **After**: Dedicated picker pages with large visual cards:
  1. Login → Company Picker (logo tiles)
  2. Company Picker → Account Picker (bank account cards)
  3. Account Picker → Main App (check writer/history)

### 2. Company Logo Support
- Added `logo_url` column to `companies` table
- Created `company-logos` storage bucket in Supabase
- Logo upload capability in company creation modal
- Fallback to styled initials for companies without logos

### 3. User Experience
- Company logo displayed prominently in app header
- "Change Company" and "Change Account" buttons always visible
- Last selection remembered per user (saved to profile)
- Only show checks for currently selected company/account
- Security: Account numbers show only last 4 digits in UI

### 4. Database Changes
- `companies.logo_url` (text) - Path to logo in storage
- `profiles.last_selected_company_id` (uuid) - Remember user's company choice
- `profiles.last_selected_account_id` (uuid) - Remember user's account choice
- Storage bucket `company-logos` with public read access

## Deployment Steps

### 1. Apply Database Migration

The migration has already been applied to the production database. It includes:
- Added `logo_url` column to companies
- Added `last_selected_company_id` and `last_selected_account_id` to profiles
- Created company-logos storage bucket
- Set up storage policies for logo uploads

If you need to reapply or verify:

```sql
-- Check if columns exist
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'companies' AND column_name = 'logo_url';

SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'profiles' AND column_name IN ('last_selected_company_id', 'last_selected_account_id');
```

### 2. Deploy Code to Railway

The code changes are in the branch `cursor/redesign-navigation-flow-c4c3`.

```bash
# Railway will automatically deploy when this branch is merged to master
# Or you can manually trigger a deploy from Railway dashboard
```

### 3. Upload Company Logos (Optional)

After deployment, admins can:
1. Log in to the app
2. Go to Company Picker
3. Click on "Add New Company" or edit existing companies
4. Upload logo images (PNG, JPG, SVG recommended)
5. Logos are stored in Supabase storage and publicly accessible

**Companies without logos will show styled initials** (e.g., "The Heritage at Jacobs Farm LLC" shows "TH" in a gradient circle).

### 4. Test the Flow

1. Log in with an admin account (e.g., brad@bradwilliamslaw.com)
2. You should see the Company Picker with cards for:
   - Northview Entertainment, LLC
   - Brad Williams, Attorney at Law PLLC
   - Select Edge Realty LLC
   - The Heritage at Jacobs Farm LLC
   - Trusted Plan Lawyers of Tennessee
3. Click a company → should navigate to Account Picker
4. Click an account → should navigate to Check Writer
5. Check Writer header should show company logo + "Change Company/Account" buttons
6. History page should only show checks for selected company/account

## Important Notes for Brad/Karen

### 1. Existing Data Safety
- **No data loss**: All existing checks, companies, and accounts remain intact
- **Table structure preserved**: The checks table schema is unchanged
- **External processes**: Automated check insertion scripts will continue to work

### 2. User Access Control
- Users only see companies they have access to (via `account_users` table)
- Admins see all companies
- Non-admin users must have at least one account assigned to see any companies

### 3. Logo Management
- Logos are **optional** - companies without logos show initials
- Supported formats: PNG, JPG, SVG, GIF, WebP
- Recommended size: 200x200 to 400x400 pixels
- Storage: Publicly accessible via Supabase CDN

### 4. Separation of Business Data
- **Critical change**: History and check writing are now scoped to one company/account
- This prevents mixing checks between businesses (e.g., "The Heritage at Jacobs Farm LLC" vs "Brad Williams, Attorney at Law PLLC")
- To work with multiple companies, users must explicitly switch using "Change Company" button

### 5. Session Persistence
- Last selected company/account is remembered per user
- Stored in both localStorage (browser) and user profile (database)
- Returning users skip pickers if their last selection is still valid

## Testing Checklist

- [ ] Login works
- [ ] Company Picker shows all user's companies
- [ ] Account Picker shows only selected company's accounts
- [ ] Main app header shows company logo/initials
- [ ] "Change Company" button works
- [ ] "Change Account" button works
- [ ] Check Writer only creates checks for selected account
- [ ] History only shows checks for selected company/account
- [ ] Uploading a company logo works
- [ ] Companies without logos show initials correctly
- [ ] Last selection is remembered after logout/login
- [ ] Non-admin users only see their assigned companies/accounts

## Rollback Plan

If issues occur, you can rollback by:

1. Revert Railway deployment to previous commit
2. Database changes are backward-compatible (columns can be left as-is)
3. If you want to remove the columns:

```sql
ALTER TABLE companies DROP COLUMN IF EXISTS logo_url;
ALTER TABLE profiles DROP COLUMN IF EXISTS last_selected_company_id;
ALTER TABLE profiles DROP COLUMN IF EXISTS last_selected_account_id;
-- Storage bucket can be deleted from Supabase dashboard
```

## Screenshots

Screenshots were captured during testing but the database had RLS restrictions. Once deployed with proper access, the flow looks like:

1. **Login Page**: Simple username/password form
2. **Company Picker**: Visual cards with company logos/initials
3. **Account Picker**: Bank account cards showing last 4 digits
4. **Main App**: Header with company logo and change buttons

## Questions or Issues?

Contact the development team or check the code comments in:
- `/src/views/CompanyPickerView.vue`
- `/src/views/AccountPickerView.vue`
- `/src/router/index.ts` (navigation guards)
- `/src/stores/app.ts` (selection state management)
