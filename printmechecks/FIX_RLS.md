# Fix Row Level Security (RLS) Issue

## The Problem
Your Supabase tables have Row Level Security (RLS) enabled but no policies defined. This blocks ALL access from the browser, including inserts, updates, and selects.

## The Solution
You need to disable RLS on all tables OR add permissive policies.

## Option 1: Disable RLS (Quickest for Development)

Go to your Supabase Dashboard and run this SQL:

1. Open: https://supabase.com/dashboard/project/cffhvhgvaidwofyceoju/sql/new
2. Paste this SQL:

```sql
-- Disable Row Level Security for all tables
-- This allows anon access for development
ALTER TABLE companies DISABLE ROW LEVEL SECURITY;
ALTER TABLE bank_accounts DISABLE ROW LEVEL SECURITY;
ALTER TABLE custom_layouts DISABLE ROW LEVEL SECURITY;
ALTER TABLE checks DISABLE ROW LEVEL SECURITY;
```

3. Click "Run"
4. Refresh your app - it should work now!

## Option 2: Enable Permissive Policies (Better for Production)

If you want to keep RLS enabled but allow public access:

```sql
-- Enable public read/write access to all tables
-- Companies
ALTER TABLE companies ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public access" ON companies FOR ALL USING (true);

-- Bank Accounts
ALTER TABLE bank_accounts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public access" ON bank_accounts FOR ALL USING (true);

-- Custom Layouts
ALTER TABLE custom_layouts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public access" ON custom_layouts FOR ALL USING (true);

-- Checks
ALTER TABLE checks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public access" ON checks FOR ALL USING (true);
```

## Verification

After running one of the above options, test by:
1. Open your app
2. Try to add a company
3. Should work without errors!

## Current Status
- ✅ Supabase connection works (tested from Node.js)
- ✅ Tables exist and are accessible with service_role key
- ❌ RLS is blocking browser access with anon key
- 📝 Need to run SQL above to fix

## Next Steps
1. Run the SQL in Supabase Dashboard SQL Editor
2. Test your app
3. Delete this file once working (or keep for reference)

