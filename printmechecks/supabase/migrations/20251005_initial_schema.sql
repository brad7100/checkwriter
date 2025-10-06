-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- Create companies table
create table companies (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  address text not null,
  city text not null,
  state text not null,
  zip text not null,
  quickbooks_realm_id text,
  quickbooks_connected boolean default false,
  quickbooks_company_name text,
  quickbooks_last_sync timestamp with time zone,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- Create bank_accounts table
create table bank_accounts (
  id uuid primary key default uuid_generate_v4(),
  company_id uuid references companies(id) on delete cascade,
  name text not null,
  bank_name text not null,
  bank_city text,
  routing_number text not null,
  account_number text not null,
  signature text not null,
  default_layout_id uuid,
  background_color text,
  quickbooks_account_id text,
  sync_to_quickbooks boolean default false,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- Create custom_layouts table
create table custom_layouts (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  is_default boolean default false,
  is_protected boolean default false,
  fields jsonb not null default '[]',
  lines jsonb not null default '[]',
  boxes jsonb not null default '[]',
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- Create checks table
create table checks (
  id uuid primary key default uuid_generate_v4(),
  company_id uuid references companies(id) on delete cascade,
  account_id uuid references bank_accounts(id) on delete cascade,
  account_holder_name text not null,
  account_holder_address text not null,
  account_holder_city text not null,
  account_holder_state text not null,
  account_holder_zip text not null,
  check_number text not null,
  date text not null,
  bank_name text not null,
  amount text not null,
  pay_to text not null,
  memo text,
  signature text not null,
  routing_number text not null,
  bank_account_number text not null,
  mail_to_name text,
  mail_to_address text,
  mail_to_suite text,
  mail_to_city text,
  mail_to_state text,
  mail_to_zip text,
  is_printed boolean default false,
  printed_date timestamp with time zone,
  expense_category text,
  quickbooks_id text,
  quickbooks_vendor_id text,
  synced_to_quickbooks boolean default false,
  synced_at timestamp with time zone,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- Create indexes for better query performance
create index idx_bank_accounts_company_id on bank_accounts(company_id);
create index idx_checks_company_id on checks(company_id);
create index idx_checks_account_id on checks(account_id);
create index idx_checks_is_printed on checks(is_printed);
create index idx_checks_check_number on checks(check_number);

-- Create updated_at trigger function
create or replace function update_updated_at_column()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- Add updated_at triggers to all tables
create trigger update_companies_updated_at before update on companies
  for each row execute function update_updated_at_column();

create trigger update_bank_accounts_updated_at before update on bank_accounts
  for each row execute function update_updated_at_column();

create trigger update_custom_layouts_updated_at before update on custom_layouts
  for each row execute function update_updated_at_column();

create trigger update_checks_updated_at before update on checks
  for each row execute function update_updated_at_column();

-- Insert the default/original layout
insert into custom_layouts (id, name, is_default, is_protected, fields, lines, boxes)
values (
  '00000000-0000-0000-0000-000000000001',
  'Original',
  true,
  true,
  '[]',
  '[]',
  '[]'
);

