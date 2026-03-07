-- NOTE: Do NOT run this if you use per-account permissions (001_users_and_permissions.sql).
-- Keeping RLS enabled so only admins and users with account_users access see data.
-- If RLS was previously disabled, run 002_reenable_rls_for_permissions.sql to fix.

-- alter table companies disable row level security;
-- alter table bank_accounts disable row level security;
-- alter table custom_layouts disable row level security;
-- alter table checks disable row level security;

