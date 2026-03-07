# Users & Per-Account Permissions

The app supports:

- **Admin**: Full access; can invite new users (no public signup), manage companies/accounts, and assign which users can use which accounts.
- **Regular users**: Can only see and use bank accounts they’ve been assigned to. New users are added by an admin only (no sign-up page).

## One-time setup in Supabase

### 1. Run the permissions migration

1. Open your [Supabase project](https://supabase.com/dashboard) → **SQL Editor** → **New query**.
2. Run the migration script: copy and run the contents of  
   `printmechecks/supabase/migrations/001_users_and_permissions.sql`.
3. Make yourself an admin (use the email you sign in with):

   ```sql
   UPDATE public.profiles SET role = 'admin' WHERE email = 'your@email.com';
   ```

### 2. Disable public signup

So only admins can add users:

1. In Supabase Dashboard go to **Authentication** → **Providers** → **Email**.
2. Turn **off** “Enable Sign Up” (or “Allow new signups”).
3. Save.

### 3. Deploy the Invite User Edge Function

Admins invite users from the app; the invite is sent by an Edge Function.

1. Install [Supabase CLI](https://supabase.com/docs/guides/cli) and link your project (`supabase link`).
2. Deploy the function:

   ```bash
   cd printmechecks
   supabase functions deploy invite-user
   ```

3. Ensure these secrets are set for the function (they usually are by default):  
   `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`.

## How to add a user (admin only)

1. Log in as an **admin**.
2. Go to **Manage** → click **Invite user**.
3. Enter the user’s **email** → **Send invite**.
4. They receive an email from Supabase to set their password and sign in.
5. After they sign in once, go to **Manage** → under each bank account use **Add user** to give them access to specific accounts.

## Behavior

- **Admin**: Sees “Manage”, can **Invite user**, and manage companies/accounts and per-account user access.
- **Non-admin**: No “Manage” tab; only sees companies/accounts they’re assigned to.
- **Checks and history**: Restricted by Supabase RLS to accounts the user can access.
