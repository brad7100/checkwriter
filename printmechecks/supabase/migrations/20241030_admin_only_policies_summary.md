# Admin-Only Access Summary for Companies, Bank Accounts, and Account Users

## Current Status: ✅ ALREADY CORRECTLY CONFIGURED

The RLS policies in Supabase project `cffhvhgvaidwofyceoju` are **already correctly configured** to restrict company and bank account management to admins only.

**No migration SQL is needed.** This document is for reference and verification purposes.

---

## Current RLS Policies

### 1. **Companies Table** ✅

#### Policy: "Companies: insert/update/delete admin only"
- **Command**: ALL (INSERT, UPDATE, DELETE)
- **USING**: `is_admin()`
- **WITH CHECK**: `is_admin()`
- **Effect**: Only admins can create, modify, or delete companies

#### Policy: "Companies: select if admin or has account access"
- **Command**: SELECT
- **USING**: 
  ```sql
  is_admin() OR EXISTS (
    SELECT 1 FROM bank_accounts ba
    JOIN account_users au ON au.bank_account_id = ba.id
    WHERE ba.company_id = companies.id 
      AND au.user_id = auth.uid()
  )
  ```
- **Effect**: 
  - Admins can see all companies
  - Non-admins can only see companies they have account access to (via `account_users`)

---

### 2. **Bank Accounts Table** ✅

#### Policy: "Bank accounts: insert/update/delete admin only"
- **Command**: ALL (INSERT, UPDATE, DELETE)
- **USING**: `is_admin()`
- **WITH CHECK**: `is_admin()`
- **Effect**: Only admins can create, modify, or delete bank accounts

#### Policy: "Bank accounts: select if admin or allowed"
- **Command**: SELECT
- **USING**: 
  ```sql
  is_admin() OR EXISTS (
    SELECT 1 FROM account_users
    WHERE account_users.user_id = auth.uid() 
      AND account_users.bank_account_id = bank_accounts.id
  )
  ```
- **Effect**: 
  - Admins can see all bank accounts
  - Non-admins can only see accounts they're assigned to (via `account_users`)

---

### 3. **Account Users Table** ✅

#### Policy: "Admins can insert account_users"
- **Command**: INSERT
- **WITH CHECK**: `is_admin()`
- **Effect**: Only admins can grant account access to users

#### Policy: "Admins can delete account_users"
- **Command**: DELETE
- **USING**: `is_admin()`
- **Effect**: Only admins can revoke account access from users

#### Policy: "Admins can read all account_users"
- **Command**: SELECT
- **USING**: `is_admin()`
- **Effect**: Admins can see all user-account assignments

#### Policy: "Users can read own account access"
- **Command**: SELECT
- **USING**: `user_id = auth.uid()`
- **Effect**: Non-admins can see which accounts they have access to

**Note**: There is NO UPDATE policy on `account_users`, which prevents anyone from modifying existing assignments. Only INSERT/DELETE are allowed.

---

### 4. **Checks Table** ✅ (User Access Preserved)

The checks table policies allow non-admin users to:
- **INSERT**: Create checks on accounts they have access to (via `account_users`)
- **UPDATE**: Edit their own checks or checks on their assigned accounts (with role-based restrictions)
- **SELECT**: View checks on their assigned accounts
- **DELETE**: Delete checks on their assigned accounts (approvers and admins only)

This ensures that regular users (Karen, etc.) can still:
- Create new checks
- Edit and print checks
- Mark checks as printed (with the new policy from this PR)
- View check history

---

## Security Model Summary

### Admins (`profiles.role = 'admin'`)
- ✅ Create, edit, delete companies
- ✅ Create, edit, delete bank accounts
- ✅ Assign/revoke users to/from accounts (`account_users`)
- ✅ Invite new users
- ✅ Reset user passwords
- ✅ Full access to all checks

### Non-Admin Users (regular users, Karen)
- ❌ Cannot create, edit, or delete companies
- ❌ Cannot create, edit, or delete bank accounts
- ❌ Cannot grant themselves access to additional accounts
- ✅ Can view companies they have account access to
- ✅ Can view bank accounts they're assigned to
- ✅ Can create, edit, and print checks on their assigned accounts
- ✅ Can mark checks as printed on their assigned accounts (new feature)
- ✅ Can view check history for their assigned accounts

---

## Helper Functions (Database)

### `is_admin()`
```sql
SELECT EXISTS (
  SELECT 1 FROM public.profiles 
  WHERE id = auth.uid() 
    AND role = 'admin'
);
```
Returns true if the current user has admin role.

### `can_approve_checks()`
```sql
SELECT EXISTS (
  SELECT 1 FROM public.profiles 
  WHERE id = auth.uid() 
    AND role IN ('admin', 'approver')
);
```
Returns true if the current user is admin or approver.

### `get_user_role()`
```sql
SELECT role FROM public.profiles 
WHERE id = auth.uid();
```
Returns the current user's role ('admin', 'approver', or 'submitter').

---

## UI Controls (Now Hidden for Non-Admins)

The following UI controls are now hidden with `v-if="store.isAdmin"`:

### CompanyPickerView
- ✅ "Add New Company" card (already hidden)

### AccountPickerView
- ✅ "Add New Account" card (already hidden)
- ✅ "Add Your First Account" button (already hidden)

### ManageView (Route: `/manage`)
- ✅ Route requires admin (router meta: `requiresAdmin: true`)
- ✅ "Add Company" button (now hidden)
- ✅ Company "Edit" buttons (now hidden)
- ✅ Company "Delete" buttons (now hidden)
- ✅ "Add Account" buttons per company (now hidden)
- ✅ Account "Edit" buttons (now hidden)
- ✅ Account "Delete" buttons (now hidden)
- ✅ "Invite user" button (now hidden)
- ✅ "Send password reset" form (now hidden)
- ✅ User assignment section per account (now hidden)
- ✅ "Add user" to account buttons (now hidden)
- ✅ Remove user from account buttons (now hidden)

### App.vue Navigation
- ✅ "Manage" nav link (already hidden with `v-if="store.isAdmin"`)

---

## Testing Checklist

- [x] Database policies already restrict INSERT/UPDATE/DELETE to admins
- [x] Non-admins cannot grant themselves account access
- [x] Non-admins can still create and manage checks on assigned accounts
- [x] UI controls hidden for non-admins
- [ ] Test as Karen (non-admin): verify no company/account management UI visible
- [ ] Test as Karen (non-admin): verify can still create/print/mark checks
- [ ] Test as admin: verify all management features work

---

## Conclusion

**No SQL migration is required.** The database policies were already correctly configured to restrict company and bank account management to admins only. This PR only adds defensive UI guards to ensure non-admin users don't see management controls they cannot use.

The security is enforced at the database level (RLS), and the UI now properly reflects these restrictions for a better user experience.
