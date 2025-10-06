# LocalStorage Usage

## Current Usage

LocalStorage is now **ONLY** used for:

### 1. Session Preferences (Non-Critical)
- `selectedCompanyId` - Remembers which company you last selected
- `selectedAccountId` - Remembers which account you last selected
- These are **session-only** and not critical data

### 2. Migration Tracking
- `migrationCompleted` - Tracks if data migration from localStorage to Supabase has been completed
- This flag prevents the migration prompt from showing repeatedly

## What's NOT in LocalStorage Anymore

All critical data is now **exclusively in Supabase**:
- ❌ Companies
- ❌ Bank Accounts
- ❌ Custom Layouts
- ❌ Checks History

## Failure Behavior

If Supabase operations fail:
- **Error is thrown** - No silent fallback to localStorage
- **User sees alert** - Clear error message displayed
- **Operation fails** - Data is NOT saved if Supabase is unreachable
- **No data loss** - Last successful Supabase state remains intact

## Benefits

1. **Single Source of Truth** - Supabase is the only database
2. **No Sync Issues** - No conflicts between localStorage and Supabase
3. **Clear Failures** - Users know immediately if save fails
4. **Cloud-First** - All data accessible from any device
5. **No Stale Data** - Always loading fresh data from Supabase

## Code Locations

### Session Storage (OK to keep)
- `src/stores/app.ts` - Lines 221-226 (load), 244-245 (save)
  - Only `selectedCompanyId` and `selectedAccountId`

### Migration Code (OK to keep)
- `src/App.vue` - Lines 38, 41, 51, 68
- `src/utils/migrateToSupabase.ts` - Lines 9-12
  - Used only for one-time migration from old localStorage data

## Testing

To verify localStorage is not being used for data:

1. Open Browser DevTools → Application → LocalStorage
2. Clear all localStorage data
3. Refresh the app
4. Add a company/account/check
5. Check localStorage - should ONLY see:
   - `selectedCompanyId`
   - `selectedAccountId`
   - `migrationCompleted`
6. No `companies`, `bankAccounts`, `customLayouts`, or `checkList` keys

## Migration Path

For existing users with localStorage data:
1. App detects old localStorage data
2. Shows migration modal
3. User clicks "Migrate Now"
4. Data moves to Supabase
5. Migration flag set
6. Old localStorage data can be manually cleared (app won't use it)

