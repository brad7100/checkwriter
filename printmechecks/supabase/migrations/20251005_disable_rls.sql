-- Disable Row Level Security for all tables
-- This allows anon access for a simple application
-- For production, you should enable RLS and add proper policies

alter table companies disable row level security;
alter table bank_accounts disable row level security;
alter table custom_layouts disable row level security;
alter table checks disable row level security;

