import { ref, computed } from 'vue'
import { defineStore } from 'pinia'
import { supabase } from '../lib/supabase'
import { authService, type AuthUser, type AuthState } from '../lib/auth'

// Interfaces
export interface Company {
  id: string
  name: string
  address: string
  city: string
  state: string
  zip: string
  quickbooksRealmId?: string
  quickbooksConnected?: boolean
  quickbooksCompanyName?: string
  quickbooksLastSync?: string
}

export interface BankAccount {
  id: string
  companyId: string
  name: string
  bankName: string
  bankCity?: string
  routingNumber: string
  accountNumber: string
  signature: string
  defaultLayoutId?: string
  backgroundColor?: string
  quickbooksAccountId?: string
  syncToQuickBooks?: boolean
}

export interface Check {
  id?: string
  companyId: string
  accountId: string
  accountHolderName: string
  accountHolderAddress: string
  accountHolderCity: string
  accountHolderState: string
  accountHolderZip: string
  checkNumber: string
  date: string
  bankName: string
  amount: string
  payTo: string
  memo: string
  signature: string
  routingNumber: string
  bankAccountNumber: string
  mailToName?: string
  mailToAddress?: string
  mailToSuite?: string
  mailToCity?: string
  mailToState?: string
  mailToZip?: string
  isPrinted?: boolean
  printedDate?: string | null
  expenseCategory?: string
  quickbooksId?: string
  quickbooksVendorId?: string
  syncedToQuickBooks?: boolean
  syncedAt?: string
}

export interface LayoutField {
  id: string
  type: 'text' | 'data'
  x: number
  y: number
  width: number
  height: number
  text?: string
  dataBinding?: string
  fontFamily: string
  fontSize: number
  fontWeight: boolean
  fontStyle: boolean
  color: string
  textAlign?: 'left' | 'center' | 'right'
}

export interface DrawingElement {
  id: string
  type: 'line' | 'box'
  x: number
  y: number
  width: number
  height: number
  strokeWidth: number
  strokeColor: string
  fillColor?: string
  rotation?: number
}

export interface CustomLayout {
  id: string
  name: string
  fields: LayoutField[]
  drawingElements?: DrawingElement[]
}

export const useAppStore = defineStore('useAppStore', () => {
  // State
  const check = ref<Check | null>(null)
  const companies = ref<Company[]>([])
  const bankAccounts = ref<BankAccount[]>([])
  const selectedCompanyId = ref('')
  const selectedAccountId = ref('')
  const customLayouts = ref<CustomLayout[]>([
    {
      id: 'original',
      name: 'Original',
      fields: [],
      drawingElements: []
    }
  ])
  const isLoading = ref(true)
  const isLoaded = ref(false)
  
  // Authentication state
  const authState = ref<AuthState>({
    user: null,
    session: null,
    loading: true,
    error: null
  })

  // Computed
  const selectedCompany = computed(() => 
    companies.value.find(c => c.id === selectedCompanyId.value)
  )

  const selectedAccount = computed(() => 
    bankAccounts.value.find(a => a.id === selectedAccountId.value)
  )

  const accountsForSelectedCompany = computed(() => 
    bankAccounts.value.filter(a => a.companyId === selectedCompanyId.value)
  )

  // Load data from Supabase exclusively
  const loadData = async () => {
    isLoading.value = true
    try {
      console.log('Loading data from Supabase...')
      
      // Load companies
      const { data: companiesData, error: companiesError } = await supabase
        .from('companies')
        .select('*')
        .order('created_at', { ascending: true })
      
      if (companiesError) {
        console.error('Error loading companies:', companiesError)
      } else {
        companies.value = (companiesData || []).map(c => ({
          id: c.id,
          name: c.name,
          address: c.address,
          city: c.city,
          state: c.state,
          zip: c.zip,
          quickbooksRealmId: c.quickbooks_realm_id,
          quickbooksConnected: c.quickbooks_connected,
          quickbooksCompanyName: c.quickbooks_company_name,
          quickbooksLastSync: c.quickbooks_last_sync
        }))
        console.log(`Loaded ${companies.value.length} companies`)
      }

      // Load bank accounts
      const { data: accountsData, error: accountsError } = await supabase
        .from('bank_accounts')
        .select('*')
        .order('created_at', { ascending: true })
      
      if (accountsError) {
        console.error('Error loading bank accounts:', accountsError)
      } else {
        bankAccounts.value = (accountsData || []).map(a => ({
          id: a.id,
          companyId: a.company_id,
          name: a.name,
          bankName: a.bank_name,
          bankCity: a.bank_city,
          routingNumber: a.routing_number,
          accountNumber: a.account_number,
          signature: a.signature,
          defaultLayoutId: a.default_layout_id,
          backgroundColor: a.background_color,
          quickbooksAccountId: a.quickbooks_account_id,
          syncToQuickBooks: a.sync_to_quickbooks
        }))
        console.log(`Loaded ${bankAccounts.value.length} bank accounts`)
      }

      // Load custom layouts
      const { data: layoutsData, error: layoutsError } = await supabase
        .from('custom_layouts')
        .select('*')
        .order('created_at', { ascending: true })
      
      if (layoutsError) {
        console.error('Error loading layouts:', layoutsError)
      } else {
        const layouts = (layoutsData || []).map(l => {
          const layoutData = l.fields || {}
          return {
            id: l.id,
            name: l.name,
            fields: layoutData.fields || [],
            drawingElements: layoutData.drawingElements || []
          }
        })
        
        // Always include original if not protected in DB
        if (!layouts.find(l => l.id === 'original')) {
          layouts.unshift({
            id: 'original',
            name: 'Original',
            fields: [],
            drawingElements: []
          })
        }
        customLayouts.value = layouts
        console.log(`Loaded ${customLayouts.value.length} layouts:`, layouts.map(l => ({ id: l.id, name: l.name })))
      }

      // Load session preferences from localStorage only
      const selectedCompData = localStorage.getItem('selectedCompanyId')
      if (selectedCompData) {
        selectedCompanyId.value = selectedCompData
      }

      const selectedAccData = localStorage.getItem('selectedAccountId')
      if (selectedAccData) {
        selectedAccountId.value = selectedAccData
      }

      isLoaded.value = true
      console.log('Data loaded successfully from Supabase')
    } catch (error) {
      console.error('Error loading data from Supabase:', error)
      alert('Failed to connect to database. Please check your internet connection and refresh.')
    } finally {
      isLoading.value = false
    }
  }

  // Save session preferences only (selected company/account)
  const saveData = () => {
    try {
      localStorage.setItem('selectedCompanyId', selectedCompanyId.value)
      localStorage.setItem('selectedAccountId', selectedAccountId.value)
    } catch (error) {
      console.error('Error saving session data:', error)
    }
  }

  // Company actions
  const addCompany = async (company: Company) => {
    try {
      // Let Supabase auto-generate the ID - don't send it
      const { data, error } = await supabase
        .from('companies')
        .insert([{
          name: company.name,
          address: company.address,
          city: company.city,
          state: company.state,
          zip: company.zip
        }])
        .select()
        .single()
      
      if (error) {
        console.error('Supabase error:', error)
        throw error
      }
      
      console.log('✅ Company added successfully:', data)
      
      // Use the company data returned from Supabase (with real ID)
      companies.value.push({
        id: data.id,
        name: data.name,
        address: data.address,
        city: data.city,
        state: data.state,
        zip: data.zip,
        quickbooksRealmId: data.quickbooks_realm_id,
        quickbooksConnected: data.quickbooks_connected,
        quickbooksCompanyName: data.quickbooks_company_name,
        quickbooksLastSync: data.quickbooks_last_sync
      })
      saveData()
      alert('Company added successfully!')
    } catch (error: any) {
      console.error('Error adding company:', error)
      alert(`Failed to add company: ${error.message || 'Please check your connection.'}`)
    }
  }

  const updateCompany = async (id: string, updates: Partial<Company>) => {
    try {
      const { error } = await supabase
        .from('companies')
        .update({
          name: updates.name,
          address: updates.address,
          city: updates.city,
          state: updates.state,
          zip: updates.zip,
          quickbooks_realm_id: updates.quickbooksRealmId,
          quickbooks_connected: updates.quickbooksConnected,
          quickbooks_company_name: updates.quickbooksCompanyName,
          quickbooks_last_sync: updates.quickbooksLastSync
        })
        .eq('id', id)
      
      if (error) throw error
      
      const index = companies.value.findIndex(c => c.id === id)
      if (index !== -1) {
        companies.value[index] = { ...companies.value[index], ...updates }
      }
      saveData()
    } catch (error) {
      console.error('Error updating company:', error)
      alert('Failed to update company. Please check your connection.')
    }
  }

  const deleteCompany = async (id: string) => {
    try {
      const { error} = await supabase
        .from('companies')
        .delete()
        .eq('id', id)
      
      if (error) throw error
      
      companies.value = companies.value.filter(c => c.id !== id)
      if (selectedCompanyId.value === id) {
        selectedCompanyId.value = ''
        selectedAccountId.value = ''
      }
      saveData()
    } catch (error) {
      console.error('Error deleting company:', error)
      alert('Failed to delete company. Please check your connection.')
    }
  }

  // Bank Account actions
  const addBankAccount = async (account: BankAccount) => {
    try {
      // Let Supabase auto-generate the ID
      const { data, error } = await supabase
        .from('bank_accounts')
        .insert([{
          company_id: account.companyId,
          name: account.name,
          bank_name: account.bankName,
          bank_city: account.bankCity,
          routing_number: account.routingNumber,
          account_number: account.accountNumber,
          signature: account.signature
        }])
        .select()
        .single()
      
      if (error) {
        console.error('Supabase error:', error)
        throw error
      }
      
      console.log('✅ Bank account added successfully:', data)
      
      // Use the data returned from Supabase (with real ID)
      bankAccounts.value.push({
        id: data.id,
        companyId: data.company_id,
        name: data.name,
        bankName: data.bank_name,
        bankCity: data.bank_city,
        routingNumber: data.routing_number,
        accountNumber: data.account_number,
        signature: data.signature,
        defaultLayoutId: data.default_layout_id,
        backgroundColor: data.background_color,
        quickbooksAccountId: data.quickbooks_account_id,
        syncToQuickbooks: data.sync_to_quickbooks
      })
      alert('Bank account added successfully!')
    } catch (error: any) {
      console.error('Error adding bank account:', error)
      alert(`Failed to add bank account: ${error.message || 'Please check your connection.'}`)
    }
  }

  const updateBankAccount = async (id: string, updates: Partial<BankAccount>) => {
    try {
      const { error } = await supabase
        .from('bank_accounts')
        .update({
          company_id: updates.companyId,
          name: updates.name,
          bank_name: updates.bankName,
          bank_city: updates.bankCity,
          routing_number: updates.routingNumber,
          account_number: updates.accountNumber,
          signature: updates.signature,
          default_layout_id: updates.defaultLayoutId,
          background_color: updates.backgroundColor,
          quickbooks_account_id: updates.quickbooksAccountId,
          sync_to_quickbooks: updates.syncToQuickBooks
        })
        .eq('id', id)
      
      if (error) throw error
      
      console.log('Supabase update successful for account:', id)
      console.log('Updates applied:', updates)
      
      // Update local state
      const index = bankAccounts.value.findIndex(a => a.id === id)
      if (index !== -1) {
        // Force reactive update by replacing the entire object
        bankAccounts.value[index] = { 
          ...bankAccounts.value[index], 
          ...updates 
        }
        // Trigger reactivity by replacing the entire array
        bankAccounts.value = [...bankAccounts.value]
      }
      
      console.log('Local state updated, account now has defaultLayoutId:', bankAccounts.value[index]?.defaultLayoutId)
    } catch (error) {
      console.error('Error updating bank account:', error)
      alert('Failed to update bank account. Please check your connection.')
    }
  }

  const deleteBankAccount = async (id: string) => {
    try {
      const { error } = await supabase
        .from('bank_accounts')
        .delete()
        .eq('id', id)
      
      if (error) throw error
      
      bankAccounts.value = bankAccounts.value.filter(a => a.id !== id)
      if (selectedAccountId.value === id) {
        selectedAccountId.value = ''
      }
    } catch (error) {
      console.error('Error deleting bank account:', error)
      alert('Failed to delete bank account. Please check your connection.')
    }
  }

  // Custom Layout actions
  const addCustomLayout = async (layout: CustomLayout) => {
    try {
      // Store everything in the fields column as a single object
      const layoutData = {
        fields: layout.fields || [],
        drawingElements: layout.drawingElements || []
      }
      
      // Let Supabase auto-generate the ID
      const { data, error } = await supabase
        .from('custom_layouts')
        .insert([{
          name: layout.name,
          fields: layoutData
        }])
        .select()
        .single()
      
      if (error) {
        console.error('Supabase error:', error)
        throw error
      }
      
      console.log('✅ Custom layout added successfully:', data)
      
      // Use the data returned from Supabase (with real ID)
      const savedData = data.fields || {}
      customLayouts.value.push({
        id: data.id,
        name: data.name,
        fields: savedData.fields || [],
        drawingElements: savedData.drawingElements || []
      })
    } catch (error: any) {
      console.error('Error adding custom layout:', error)
      alert(`Failed to add layout: ${error.message}`)
    }
  }

  const updateCustomLayout = async (id: string, updates: Partial<CustomLayout>) => {
    try {
      // Store everything in the fields column as a single object
      const layoutData = {
        fields: updates.fields || [],
        drawingElements: updates.drawingElements || []
      }
      
      const { error } = await supabase
        .from('custom_layouts')
        .update({
          name: updates.name,
          fields: layoutData
        })
        .eq('id', id)
      
      if (error) {
        console.error('Supabase error:', error)
        throw error
      }
      
      console.log('✅ Custom layout updated successfully')
      
      const index = customLayouts.value.findIndex(l => l.id === id)
      if (index !== -1) {
        customLayouts.value[index] = { ...customLayouts.value[index], ...updates }
      }
    } catch (error: any) {
      console.error('Error updating custom layout:', error)
      alert(`Failed to update layout: ${error.message}`)
    }
  }

  const deleteCustomLayout = async (id: string) => {
    if (id === 'original') return // Can't delete original
    
    try {
      const { error } = await supabase
        .from('custom_layouts')
        .delete()
        .eq('id', id)
      
      if (error) throw error
      
      customLayouts.value = customLayouts.value.filter(l => l.id !== id)
    } catch (error) {
      console.error('Error deleting custom layout:', error)
      // Removed localStorage fallback
      customLayouts.value = customLayouts.value.filter(l => l.id !== id)
    }
    saveData()
  }

  // Check actions
  const saveCheck = async (checkData: Check) => {
    try {
      const checkPayload = {
        company_id: checkData.companyId,
        account_id: checkData.accountId,
        account_holder_name: checkData.accountHolderName,
        account_holder_address: checkData.accountHolderAddress,
        account_holder_city: checkData.accountHolderCity,
        account_holder_state: checkData.accountHolderState,
        account_holder_zip: checkData.accountHolderZip,
        check_number: checkData.checkNumber,
        date: checkData.date,
        bank_name: checkData.bankName,
        amount: checkData.amount,
        pay_to: checkData.payTo,
        memo: checkData.memo,
        signature: checkData.signature,
        routing_number: checkData.routingNumber,
        bank_account_number: checkData.bankAccountNumber,
        mail_to_name: checkData.mailToName,
        mail_to_address: checkData.mailToAddress,
        mail_to_suite: checkData.mailToSuite,
        mail_to_city: checkData.mailToCity,
        mail_to_state: checkData.mailToState,
        mail_to_zip: checkData.mailToZip,
        is_printed: checkData.isPrinted,
        printed_date: checkData.printedDate,
        expense_category: checkData.expenseCategory,
        quickbooks_id: checkData.quickbooksId,
        quickbooks_vendor_id: checkData.quickbooksVendorId,
        synced_to_quickbooks: checkData.syncedToQuickBooks,
        synced_at: checkData.syncedAt
      }

      let data, error

      if (checkData.id) {
        // Update existing check
        const result = await supabase
          .from('checks')
          .update(checkPayload)
          .eq('id', checkData.id)
          .select()
          .single()
        data = result.data
        error = result.error
        console.log('✅ Check updated successfully:', data)
      } else {
        // Insert new check
        const result = await supabase
          .from('checks')
          .insert([checkPayload])
          .select()
          .single()
        data = result.data
        error = result.error
        console.log('✅ Check created successfully:', data)
      }
      
      if (error) {
        console.error('Supabase error:', error)
        throw error
      }
      
      return data
    } catch (error: any) {
      console.error('Error saving check:', error)
      alert(`Failed to save check: ${error.message}`)
      throw error
    }
  }

  const updateCheck = async (id: string, updates: Partial<Check>) => {
    try {
      const { error } = await supabase
        .from('checks')
        .update({
          is_printed: updates.isPrinted,
          printed_date: updates.printedDate,
          quickbooks_id: updates.quickbooksId,
          quickbooks_vendor_id: updates.quickbooksVendorId,
          synced_to_quickbooks: updates.syncedToQuickBooks,
          synced_at: updates.syncedAt
        })
        .eq('id', id)
      
      if (error) throw error
    } catch (error) {
      console.error('Error updating check:', error)
      throw error
    }
  }

  const getChecks = async () => {
    try {
      const { data, error } = await supabase
        .from('checks')
        .select('*')
        .order('created_at', { ascending: false })
      
      if (error) throw error
      
      return data?.map(c => ({
        id: c.id,
        companyId: c.company_id,
        accountId: c.account_id,
        accountHolderName: c.account_holder_name,
        accountHolderAddress: c.account_holder_address,
        accountHolderCity: c.account_holder_city,
        accountHolderState: c.account_holder_state,
        accountHolderZip: c.account_holder_zip,
        checkNumber: c.check_number,
        date: c.date,
        bankName: c.bank_name,
        amount: c.amount,
        payTo: c.pay_to,
        memo: c.memo,
        signature: c.signature,
        routingNumber: c.routing_number,
        bankAccountNumber: c.bank_account_number,
        mailToName: c.mail_to_name,
        mailToAddress: c.mail_to_address,
        mailToSuite: c.mail_to_suite,
        mailToCity: c.mail_to_city,
        mailToState: c.mail_to_state,
        mailToZip: c.mail_to_zip,
        isPrinted: c.is_printed,
        printedDate: c.printed_date,
        expenseCategory: c.expense_category,
        quickbooksId: c.quickbooks_id,
        quickbooksVendorId: c.quickbooks_vendor_id,
        syncedToQuickBooks: c.synced_to_quickbooks,
        syncedAt: c.synced_at
      })) || []
    } catch (error) {
      console.error('Error getting checks:', error)
      throw error
    }
  }

  // QuickBooks functions (stubs for now)
  const connectQuickBooks = async (companyId: string) => {
    console.log('QuickBooks connection not implemented yet for company:', companyId)
    alert('QuickBooks integration coming soon!')
  }

  const disconnectQuickBooks = async (companyId: string) => {
    const company = companies.value.find(c => c.id === companyId)
    if (company) {
      company.quickbooksConnected = false
      company.quickbooksRealmId = undefined
      company.quickbooksCompanyName = undefined
      await updateCompany(companyId, {
        quickbooksConnected: false,
        quickbooksRealmId: undefined,
        quickbooksCompanyName: undefined
      })
    }
  }

  const syncCheckToQuickBooks = async (check: Check) => {
    console.log('QuickBooks sync not implemented yet for check:', check)
    alert('QuickBooks integration coming soon!')
  }

  const getQBAccounts = async (companyId: string) => {
    console.log('QuickBooks accounts not implemented yet for company:', companyId)
    return []
  }

  const getQBVendors = async (companyId: string) => {
    console.log('QuickBooks vendors not implemented yet for company:', companyId)
    return []
  }

  // Initialize
  loadData()

  // Authentication methods
  const initializeAuth = () => {
    authService.subscribe((state) => {
      authState.value = state
    })
  }

  const signOut = async () => {
    const { error } = await authService.signOut()
    if (!error) {
      // Clear all data when signing out
      companies.value = []
      bankAccounts.value = []
      customLayouts.value = [{
        id: 'original',
        name: 'Original',
        fields: [],
        drawingElements: []
      }]
      selectedCompanyId.value = ''
      selectedAccountId.value = ''
      isLoaded.value = false
    }
    return { error }
  }

  return {
    check,
    companies,
    bankAccounts,
    selectedCompanyId,
    selectedAccountId,
    customLayouts,
    isLoading,
    isLoaded,
    authState,
    selectedCompany,
    selectedAccount,
    accountsForSelectedCompany,
    loadData,
    saveData,
    addCompany,
    updateCompany,
    deleteCompany,
    addBankAccount,
    updateBankAccount,
    deleteBankAccount,
    addCustomLayout,
    updateCustomLayout,
    deleteCustomLayout,
    saveCheck,
    updateCheck,
    getChecks,
    connectQuickBooks,
    disconnectQuickBooks,
    syncCheckToQuickBooks,
    getQBAccounts,
    getQBVendors,
    initializeAuth,
    signOut
  }
})
