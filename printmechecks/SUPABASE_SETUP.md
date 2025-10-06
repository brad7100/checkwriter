# Supabase Integration Setup

## Overview
Your check printing application is now integrated with Supabase for cloud-based data persistence. All data is synchronized to your Supabase instance while maintaining localStorage as a fallback for reliability.

## Supabase Instance
- **URL**: https://cffhvhgvaidwofyceoju.supabase.co
- **Project Ref**: cffhvhgvaidwofyceoju

## Database Schema

### Tables Created

1. **companies**
   - Stores company information
   - Fields: id, name, address, city, state, zip, QuickBooks integration fields
   - Auto-timestamps: created_at, updated_at

2. **bank_accounts**
   - Stores bank account details linked to companies
   - Fields: id, company_id, name, bank details, routing/account numbers, signature, layout preferences, background color
   - Includes QuickBooks sync settings
   - Auto-timestamps: created_at, updated_at

3. **custom_layouts**
   - Stores custom check layouts
   - Fields: id, name, is_default, is_protected, fields (JSON), lines (JSON), boxes (JSON)
   - Auto-timestamps: created_at, updated_at

4. **checks**
   - Stores all check records
   - Fields: All check data including payee, amount, memo, addresses, print status, QuickBooks sync status
   - Auto-timestamps: created_at, updated_at

## Features

### Automatic Synchronization
- All CRUD operations (Create, Read, Update, Delete) are automatically synced to Supabase
- Real-time updates across devices/browsers
- Fallback to localStorage if Supabase is unavailable

### Data Migration
The system will automatically:
1. Try to load data from Supabase first
2. Fall back to localStorage if Supabase fails
3. Sync localStorage changes to Supabase when connection is restored

### Smart Caching
- Session data (selected company/account) is stored in localStorage for quick access
- Full data is loaded from Supabase on app startup
- Updates are instantly reflected in the UI and synced to the cloud

## Files Modified

### Core Store (`src/stores/app.ts`)
- Added Supabase client import
- Converted all data operations to async
- Implemented fallback mechanisms for offline support
- Added `saveCheck()`, `updateCheck()`, and `getChecks()` methods

### Check Printer (`src/components/CheckPrinter.vue`)
- Updated to use async store methods
- Check saving now syncs to Supabase
- Print status updates are persisted to cloud

### History View (`src/views/HistoryView.vue`)
- Loads check history from Supabase
- Updates print status in cloud
- Batch operations sync all changes

## Database Access

You can access your Supabase dashboard at:
https://supabase.com/dashboard/project/cffhvhgvaidwofyceoju

From there you can:
- View all your data in the Table Editor
- Run SQL queries
- Monitor API usage
- Set up additional security rules (Row Level Security)
- Create backups

## Security Notes

### Current Setup
- Using the anon key for basic operations
- All data is currently accessible to anyone with the key
- Suitable for development and single-user scenarios

### Recommended Next Steps for Production
1. Enable Row Level Security (RLS) on all tables
2. Implement authentication (Supabase Auth)
3. Create policies to restrict access to user's own data
4. Use service role key only on backend for sensitive operations

## Backup & Recovery

### Automatic Backups
Supabase automatically backs up your database. You can restore from backups in the dashboard.

### Manual Export
```bash
cd /Users/bradwilliams/CheckRequest/printmechecks
supabase db dump -f backup.sql --password 'Gamafore!1'
```

### Manual Import
```bash
supabase db reset --password 'Gamafore!1'
```

## Troubleshooting

### If data doesn't sync
1. Check your internet connection
2. Verify Supabase is running: https://status.supabase.com
3. Check browser console for errors
4. Data will fallback to localStorage automatically

### To reset local data
1. Clear browser localStorage
2. Refresh the page
3. Data will reload from Supabase

### To view migrations
```bash
cd /Users/bradwilliams/CheckRequest/printmechecks
ls -la supabase/migrations/
```

## Development Commands

### View database status
```bash
supabase db remote status --password 'Gamafore!1'
```

### Create new migration
```bash
supabase migration new migration_name
```

### Apply migrations
```bash
supabase db push --password 'Gamafore!1'
```

## API Endpoints

Your application uses these Supabase REST API endpoints:
- `GET /rest/v1/companies` - List all companies
- `POST /rest/v1/companies` - Create a company
- `PATCH /rest/v1/companies?id=eq.{id}` - Update a company
- `DELETE /rest/v1/companies?id=eq.{id}` - Delete a company

Similar endpoints exist for `bank_accounts`, `custom_layouts`, and `checks`.

## Performance

- Initial load fetches all data (companies, accounts, layouts)
- Subsequent operations are individual updates
- Consider pagination for checks if you exceed 1000+ records

## Future Enhancements

Possible improvements:
1. Real-time subscriptions for multi-user collaboration
2. Supabase Storage for check images/signatures
3. Supabase Edge Functions for complex business logic
4. Authentication for multi-user access
5. Row-level security policies
6. Audit logs using database triggers

