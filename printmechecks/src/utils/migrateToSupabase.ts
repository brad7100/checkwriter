import { supabase } from '../lib/supabase'
import type { Company, BankAccount, CustomLayout, Check } from '../stores/app'

export async function migrateLocalStorageToSupabase() {
  try {
    console.log('Starting migration from localStorage to Supabase...')

    // Get data from localStorage
    const companiesData = localStorage.getItem('companies')
    const accountsData = localStorage.getItem('bankAccounts')
    const layoutsData = localStorage.getItem('customLayouts')
    const checksData = localStorage.getItem('checkList')

    let migratedCount = 0

    // Migrate companies
    if (companiesData) {
      const companies: Company[] = JSON.parse(companiesData)
      console.log(`Found ${companies.length} companies in localStorage`)
      
      for (const company of companies) {
        const { error } = await supabase
          .from('companies')
          .upsert({
            id: company.id,
            name: company.name,
            address: company.address,
            city: company.city,
            state: company.state,
            zip: company.zip,
            quickbooks_realm_id: company.quickbooksRealmId,
            quickbooks_connected: company.quickbooksConnected,
            quickbooks_company_name: company.quickbooksCompanyName,
            quickbooks_last_sync: company.quickbooksLastSync
          }, { onConflict: 'id' })
        
        if (!error) migratedCount++
      }
      console.log(`Migrated ${migratedCount} companies`)
    }

    // Migrate bank accounts
    migratedCount = 0
    if (accountsData) {
      const accounts: BankAccount[] = JSON.parse(accountsData)
      console.log(`Found ${accounts.length} bank accounts in localStorage`)
      
      for (const account of accounts) {
        const { error } = await supabase
          .from('bank_accounts')
          .upsert({
            id: account.id,
            company_id: account.companyId,
            name: account.name,
            bank_name: account.bankName,
            bank_city: account.bankCity,
            routing_number: account.routingNumber,
            account_number: account.accountNumber,
            signature: account.signature,
            default_layout_id: account.defaultLayoutId,
            background_color: account.backgroundColor,
            quickbooks_account_id: account.quickbooksAccountId,
            sync_to_quickbooks: account.syncToQuickBooks
          }, { onConflict: 'id' })
        
        if (!error) migratedCount++
      }
      console.log(`Migrated ${migratedCount} bank accounts`)
    }

    // Migrate custom layouts
    migratedCount = 0
    if (layoutsData) {
      const layouts: CustomLayout[] = JSON.parse(layoutsData)
      console.log(`Found ${layouts.length} custom layouts in localStorage`)
      
      for (const layout of layouts) {
        if (layout.id === 'original') continue // Skip the original placeholder
        
        const lines = layout.drawingElements?.filter(el => el.type === 'line') || []
        const boxes = layout.drawingElements?.filter(el => el.type === 'box') || []
        
        const { error } = await supabase
          .from('custom_layouts')
          .upsert({
            id: layout.id,
            name: layout.name,
            fields: layout.fields,
            lines: lines,
            boxes: boxes,
            is_default: false,
            is_protected: false
          }, { onConflict: 'id' })
        
        if (!error) migratedCount++
      }
      console.log(`Migrated ${migratedCount} custom layouts`)
    }

    // Migrate checks
    migratedCount = 0
    if (checksData) {
      const checks: Check[] = JSON.parse(checksData)
      console.log(`Found ${checks.length} checks in localStorage`)
      
      for (const check of checks) {
        const { error } = await supabase
          .from('checks')
          .upsert({
            id: check.id,
            company_id: check.companyId,
            account_id: check.accountId,
            account_holder_name: check.accountHolderName,
            account_holder_address: check.accountHolderAddress,
            account_holder_city: check.accountHolderCity,
            account_holder_state: check.accountHolderState,
            account_holder_zip: check.accountHolderZip,
            check_number: check.checkNumber,
            date: check.date,
            bank_name: check.bankName,
            amount: check.amount,
            pay_to: check.payTo,
            memo: check.memo,
            signature: check.signature,
            routing_number: check.routingNumber,
            bank_account_number: check.bankAccountNumber,
            mail_to_name: check.mailToName,
            mail_to_address: check.mailToAddress,
            mail_to_suite: check.mailToSuite,
            mail_to_city: check.mailToCity,
            mail_to_state: check.mailToState,
            mail_to_zip: check.mailToZip,
            is_printed: check.isPrinted,
            printed_date: check.printedDate,
            expense_category: check.expenseCategory,
            quickbooks_id: check.quickbooksId,
            quickbooks_vendor_id: check.quickbooksVendorId,
            synced_to_quickbooks: check.syncedToQuickBooks,
            synced_at: check.syncedAt
          }, { onConflict: 'id' })
        
        if (!error) migratedCount++
      }
      console.log(`Migrated ${migratedCount} checks`)
    }

    console.log('Migration completed successfully!')
    return true
  } catch (error) {
    console.error('Migration error:', error)
    return false
  }
}

export async function checkSupabaseConnection() {
  try {
    const { data, error } = await supabase.from('companies').select('count')
    if (error) {
      console.error('Supabase connection error:', error)
      return false
    }
    console.log('Supabase connection successful')
    return true
  } catch (error) {
    console.error('Supabase connection failed:', error)
    return false
  }
}

