-- Add logo_url column to companies table
alter table companies add column if not exists logo_url text;

-- Add last_selected_company_id to profiles table to remember user's selection
-- (profiles table is managed by auth, but we can add custom columns)
-- If profiles table doesn't have this yet, it will be added
alter table profiles add column if not exists last_selected_company_id uuid references companies(id) on delete set null;
alter table profiles add column if not exists last_selected_account_id uuid references bank_accounts(id) on delete set null;

-- Create a storage bucket for company logos (if not exists)
insert into storage.buckets (id, name, public)
values ('company-logos', 'company-logos', true)
on conflict (id) do nothing;

-- Allow authenticated users to upload logos
create policy "Allow authenticated users to upload company logos"
on storage.objects for insert
to authenticated
with check (bucket_id = 'company-logos');

-- Allow public read access to logos
create policy "Allow public read access to company logos"
on storage.objects for select
to public
using (bucket_id = 'company-logos');

-- Allow users to update their own company logos (admin check would be in app logic)
create policy "Allow authenticated users to update company logos"
on storage.objects for update
to authenticated
using (bucket_id = 'company-logos');

-- Allow authenticated users to delete company logos
create policy "Allow authenticated users to delete company logos"
on storage.objects for delete
to authenticated
using (bucket_id = 'company-logos');
