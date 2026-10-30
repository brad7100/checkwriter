<template>
  <div class="account-picker-container">
    <div class="picker-header">
      <div class="company-header">
        <div class="company-logo-small">
          <img
            v-if="store.selectedCompany?.logo_url"
            :src="getLogoUrl(store.selectedCompany.logo_url)"
            :alt="store.selectedCompany.name"
          />
          <div v-else class="company-logo-placeholder-small">
            {{ getInitials(store.selectedCompany?.name || '') }}
          </div>
        </div>
        <div class="company-info">
          <h2>{{ store.selectedCompany?.name }}</h2>
          <button class="btn btn-outline-light btn-sm" @click="changeCompany">
            <i class="bi bi-arrow-left-circle"></i> Change Company
          </button>
        </div>
      </div>
      <h1>Select a Bank Account</h1>
      <p class="subtitle">Choose which account you want to work with</p>
    </div>

    <div class="accounts-grid">
      <div
        v-for="account in store.accountsForSelectedCompany"
        :key="account.id"
        class="account-card"
        @click="selectAccount(account.id)"
      >
        <div class="account-icon">
          <i class="bi bi-bank"></i>
          <span v-if="unprintedCounts[account.id] > 0" 
                class="badge bg-danger position-absolute top-0 start-100 translate-middle">
            {{ unprintedCounts[account.id] }}
          </span>
        </div>
        <div class="account-info">
          <h3 class="account-name">{{ account.name }}</h3>
          <p class="bank-name">{{ account.bankName }}</p>
          <p class="account-number">•••• {{ getLastFourDigits(account.accountNumber) }}</p>
        </div>
      </div>

      <!-- Add Account Card (Admin Only) -->
      <div
        v-if="store.isAdmin"
        class="account-card add-account-card"
        @click="showAddAccountModal = true"
      >
        <div class="add-account-content">
          <i class="bi bi-plus-circle"></i>
          <span>Add New Account</span>
        </div>
      </div>
    </div>

    <!-- Empty State -->
    <div v-if="store.accountsForSelectedCompany.length === 0" class="empty-state">
      <i class="bi bi-bank"></i>
      <h3>No Bank Accounts</h3>
      <p v-if="!store.isAdmin">Please contact your administrator to add a bank account.</p>
      <button v-if="store.isAdmin" class="btn btn-primary" @click="showAddAccountModal = true">
        <i class="bi bi-plus-circle"></i> Add Your First Account
      </button>
    </div>

    <!-- Add Account Modal -->
    <div class="modal fade" :class="{ show: showAddAccountModal }" :style="{ display: showAddAccountModal ? 'block' : 'none' }" tabindex="-1">
      <div class="modal-dialog">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Add Bank Account to {{ store.selectedCompany?.name }}</h5>
            <button type="button" class="btn-close" @click="closeAddAccountModal"></button>
          </div>
          <div class="modal-body">
            <form @submit.prevent="saveAccount">
              <div class="mb-3">
                <label class="form-label">Account Name *</label>
                <input type="text" class="form-control" v-model="newAccount.name" placeholder="e.g., Operating Account" required>
              </div>
              <div class="mb-3">
                <label class="form-label">Bank Name *</label>
                <input type="text" class="form-control" v-model="newAccount.bankName" required>
              </div>
              <div class="mb-3">
                <label class="form-label">Bank City</label>
                <input type="text" class="form-control" v-model="newAccount.bankCity">
              </div>
              <div class="mb-3">
                <label class="form-label">Routing Number *</label>
                <input type="text" class="form-control" v-model="newAccount.routingNumber" required>
              </div>
              <div class="mb-3">
                <label class="form-label">Account Number *</label>
                <input type="text" class="form-control" v-model="newAccount.accountNumber" required>
                <small class="form-text text-muted">Only last 4 digits will be shown in the interface</small>
              </div>
              <div class="mb-3">
                <label class="form-label">Signature *</label>
                <input type="text" class="form-control" v-model="newAccount.signature" required>
              </div>
            </form>
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-secondary" @click="closeAddAccountModal">Cancel</button>
            <button type="button" class="btn btn-primary" @click="saveAccount" :disabled="isSaving">
              <span v-if="isSaving" class="spinner-border spinner-border-sm me-2"></span>
              {{ isSaving ? 'Saving...' : 'Save Account' }}
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal Backdrop -->
    <div class="modal-backdrop fade" :class="{ show: showAddAccountModal }" 
         :style="{ display: showAddAccountModal ? 'block' : 'none' }"></div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, watch } from 'vue'
import { useAppStore } from '../stores/app'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'

const store = useAppStore()
const router = useRouter()

const showAddAccountModal = ref(false)
const isSaving = ref(false)

const newAccount = reactive({
  name: '',
  bankName: '',
  bankCity: '',
  routingNumber: '',
  accountNumber: '',
  signature: ''
})

// Load unprinted check counts for each account
const unprintedCounts = ref<Record<string, number>>({})

const loadUnprintedCounts = async () => {
  for (const account of store.accountsForSelectedCompany) {
    const checks = await store.getUnprintedChecks(account.id)
    unprintedCounts.value[account.id] = checks.length
  }
}

// Load counts on mount and when company changes
onMounted(() => {
  loadUnprintedCounts()
})

watch(() => store.selectedCompanyId, () => {
  loadUnprintedCounts()
})

const getInitials = (name: string) => {
  return name
    .split(' ')
    .map(word => word[0])
    .join('')
    .toUpperCase()
    .substring(0, 2)
}

const getLogoUrl = (logoPath: string) => {
  if (!logoPath) return ''
  if (logoPath.startsWith('http')) return logoPath
  if (logoPath.startsWith('/')) return logoPath // Static file from public directory
  
  const { data } = supabase.storage
    .from('company-logos')
    .getPublicUrl(logoPath)
  
  return data.publicUrl
}

const getLastFourDigits = (accountNumber: string) => {
  if (!accountNumber) return '0000'
  return accountNumber.slice(-4)
}

const changeCompany = () => {
  router.push('/company-picker')
}

const selectAccount = async (accountId: string) => {
  store.selectedAccountId = accountId
  store.saveData()
  
  // Save the last selection to the user's profile
  try {
    const { data: { user } } = await supabase.auth.getUser()
    if (user) {
      await supabase
        .from('profiles')
        .update({
          last_selected_company_id: store.selectedCompanyId,
          last_selected_account_id: accountId
        })
        .eq('id', user.id)
    }
  } catch (error) {
    console.error('Error saving last selection:', error)
  }
  
  router.push('/')
}

const saveAccount = async () => {
  if (!newAccount.name || !newAccount.bankName || !newAccount.routingNumber || !newAccount.accountNumber || !newAccount.signature) {
    alert('Please fill in all required fields')
    return
  }

  isSaving.value = true

  try {
    const { data, error } = await supabase
      .from('bank_accounts')
      .insert([{
        company_id: store.selectedCompanyId,
        name: newAccount.name,
        bank_name: newAccount.bankName,
        bank_city: newAccount.bankCity,
        routing_number: newAccount.routingNumber,
        account_number: newAccount.accountNumber,
        signature: newAccount.signature
      }])
      .select()
      .single()

    if (error) throw error

    // Add to local state
    store.bankAccounts.push({
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
      syncToQuickBooks: data.sync_to_quickbooks
    })

    closeAddAccountModal()
    alert('Bank account added successfully!')
  } catch (error: any) {
    console.error('Error adding bank account:', error)
    alert(`Failed to add bank account: ${error.message || 'Please check your connection.'}`)
  } finally {
    isSaving.value = false
  }
}

const closeAddAccountModal = () => {
  showAddAccountModal.value = false
  newAccount.name = ''
  newAccount.bankName = ''
  newAccount.bankCity = ''
  newAccount.routingNumber = ''
  newAccount.accountNumber = ''
  newAccount.signature = ''
}

onMounted(() => {
  // If no company is selected, redirect to company picker
  if (!store.selectedCompanyId) {
    router.push('/company-picker')
    return
  }
  
  // If user only has access to one account for this company, auto-select it and move to main app
  if (store.accountsForSelectedCompany.length === 1) {
    selectAccount(store.accountsForSelectedCompany[0].id)
  }
})
</script>

<style scoped>
.account-picker-container {
  min-height: 100vh;
  background: #ffffff;
  padding: 40px 20px;
}

.picker-header {
  text-align: center;
  color: #2d3748;
  margin-bottom: 40px;
}

.company-header {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 20px;
  margin-bottom: 30px;
  padding: 20px;
  background: #f7fafc;
  border: 1px solid #e2e8f0;
  border-radius: 12px;
  max-width: 600px;
  margin-left: auto;
  margin-right: auto;
}

.company-logo-small {
  width: 60px;
  height: 60px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: white;
  border-radius: 8px;
  padding: 8px;
}

.company-logo-small img {
  max-width: 100%;
  max-height: 100%;
  object-fit: contain;
}

.company-logo-placeholder-small {
  width: 60px;
  height: 60px;
  border-radius: 8px;
  background: #f7fafc;
  border: 2px solid #e2e8f0;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1.5rem;
  font-weight: 700;
  color: #4a5568;
}

.company-info {
  text-align: left;
}

.company-info h2 {
  margin: 0 0 8px 0;
  font-size: 1.5rem;
  font-weight: 600;
  color: #2d3748;
}

.picker-header h1 {
  font-size: 2.5rem;
  font-weight: 700;
  margin-bottom: 10px;
  color: #2d3748;
}

.picker-header .subtitle {
  font-size: 1.1rem;
  color: #718096;
}

.accounts-grid {
  max-width: 1200px;
  margin: 0 auto;
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 24px;
  padding: 0 20px;
}

.account-card {
  background: white;
  border-radius: 16px;
  padding: 32px 24px;
  cursor: pointer;
  transition: all 0.3s ease;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
  display: flex;
  align-items: center;
  gap: 20px;
}

.account-card:hover {
  transform: translateY(-8px);
  box-shadow: 0 12px 24px rgba(0, 0, 0, 0.15);
}

.account-icon {
  width: 64px;
  height: 64px;
  border-radius: 12px;
  background: #f7fafc;
  border: 2px solid #e2e8f0;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.account-icon i {
  font-size: 2rem;
  color: #4a5568;
}

.account-info {
  flex: 1;
  text-align: left;
}

.account-name {
  font-size: 1.3rem;
  font-weight: 600;
  margin-bottom: 4px;
  color: #2d3748;
}

.bank-name {
  font-size: 0.95rem;
  color: #718096;
  margin-bottom: 4px;
}

.account-number {
  font-size: 0.9rem;
  color: #a0aec0;
  font-family: monospace;
  margin: 0;
}

.add-account-card {
  border: 2px dashed #cbd5e0;
  background: rgba(255, 255, 255, 0.6);
  justify-content: center;
}

.add-account-card:hover {
  border-color: #0d6efd;
  background: white;
}

.add-account-content {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
  color: #4a5568;
  font-size: 1rem;
  font-weight: 600;
}

.add-account-content i {
  font-size: 3rem;
  color: #0d6efd;
}

.empty-state {
  max-width: 500px;
  margin: 60px auto;
  text-align: center;
  background: white;
  padding: 60px 40px;
  border-radius: 16px;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
}

.empty-state i {
  font-size: 4rem;
  color: #cbd5e0;
  margin-bottom: 20px;
}

.empty-state h3 {
  font-size: 1.5rem;
  font-weight: 600;
  margin-bottom: 12px;
  color: #2d3748;
}

.empty-state p {
  color: #718096;
  margin-bottom: 24px;
}

.modal {
  z-index: 1050;
}

.modal-backdrop {
  z-index: 1040;
}

.modal.show {
  display: block !important;
}

.modal-backdrop.show {
  opacity: 0.5;
}
</style>
