<template>
  <div>
    <main>
      <div class="container">
        <div class="d-flex justify-content-between align-items-center mb-4">
          <h2>Manage Companies & Accounts</h2>
          <button class="btn btn-primary" @click="showAddCompanyModal = true">
            <i class="bi bi-plus-lg"></i> Add Company
          </button>
        </div>
        
        <!-- Companies with Nested Accounts -->
        <div v-if="store.companies.length > 0">
          <div v-for="company in store.companies" :key="company.id" class="company-section mb-4">
            <!-- Company Card -->
            <div class="card company-card">
              <div class="card-header company-header">
                <div class="d-flex justify-content-between align-items-center">
                  <div>
                    <h4>
                      <i class="bi bi-building"></i> {{ company.name }}
                    </h4>
                    <small class="text-muted">
                      {{ company.address }}, {{ company.city }}, {{ company.state }} {{ company.zip }}
                    </small>
                  </div>
                  <div>
                    <button class="btn btn-outline-secondary btn-sm me-2" @click="editCompany(company)">
                      <i class="bi bi-pencil"></i> Edit
                    </button>
                    <button class="btn btn-outline-danger btn-sm" @click="deleteCompany(company.id)">
                      <i class="bi bi-trash"></i> Delete
                    </button>
                  </div>
                </div>
              </div>
              
              <div class="card-body">
                <!-- QuickBooks Connection Status -->
                <div v-if="company.quickbooksConnected" class="alert alert-success mb-3">
                  <i class="bi bi-check-circle-fill"></i>
                  Connected to QuickBooks: <strong>{{ company.quickbooksCompanyName }}</strong>
                  <button class="btn btn-sm btn-outline-danger float-end" @click="store.disconnectQuickBooks(company.id)">
                    Disconnect
                  </button>
                </div>
                <div v-else class="alert alert-info mb-3">
                  <i class="bi bi-info-circle"></i>
                  Not connected to QuickBooks
                  <button class="btn btn-sm btn-primary float-end" @click="store.connectQuickBooks(company.id)">
                    <i class="bi bi-box-arrow-up-right"></i> Connect to QuickBooks
                  </button>
                </div>
                
                <!-- Bank Accounts for this Company -->
                <div class="accounts-section mt-3">
                  <div class="d-flex justify-content-between align-items-center mb-3">
                    <h5 class="mb-0"><i class="bi bi-bank2 me-2"></i>Bank Accounts</h5>
                    <button class="btn btn-outline-primary btn-sm" @click="showAddAccountModalForCompany(company.id)">
                      <i class="bi bi-plus"></i> Add Account
                    </button>
                  </div>
                  
                  <div v-if="getCompanyAccounts(company.id).length > 0" class="row">
                    <div class="col-md-6 mb-3" v-for="account in getCompanyAccounts(company.id)" :key="account.id">
                      <div class="card account-card">
                        <div class="card-body">
                          <h6 class="card-title">
                            <i class="bi bi-credit-card"></i> {{ account.name }}
                            <span v-if="account.backgroundColor" 
                                  class="badge ms-2" 
                                  :style="{ backgroundColor: account.backgroundColor }">
                              Colored
                            </span>
                          </h6>
                          <p class="card-text small">
                            <strong>Bank:</strong> {{ account.bankName }}<br>
                            <strong>Routing:</strong> {{ account.routingNumber }}<br>
                            <strong>Account:</strong> ****{{ account.accountNumber.slice(-4) }}<br>
                            <strong>Default Layout:</strong> {{ getLayoutName(account.defaultLayoutId) }}
                          </p>
                          <div class="btn-group btn-group-sm" role="group">
                            <button class="btn btn-outline-primary" @click="editAccount(account)">
                              <i class="bi bi-pencil"></i> Edit
                            </button>
                            <button class="btn btn-outline-danger" @click="deleteAccount(account.id)">
                              <i class="bi bi-trash"></i> Delete
                            </button>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                  
                  <div v-else class="alert alert-info mb-0">
                    <i class="bi bi-info-circle me-2"></i>No bank accounts yet. Click "Add Account" to create one.
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
        
        <div v-else class="alert alert-info">
          <i class="bi bi-info-circle me-2"></i>No companies added yet. Click "Add Company" to get started.
        </div>
      </div>
    </main>

    <!-- Add/Edit Company Modal -->
    <div class="modal fade" :class="{ show: showAddCompanyModal || showEditCompanyModal }" 
         :style="{ display: (showAddCompanyModal || showEditCompanyModal) ? 'block' : 'none' }" 
         tabindex="-1">
      <div class="modal-dialog">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">{{ showEditCompanyModal ? 'Edit' : 'Add' }} Company</h5>
            <button type="button" class="btn-close" @click="closeCompanyModal"></button>
          </div>
          <div class="modal-body">
            <form>
              <div class="mb-3">
                <label class="form-label">Company Name *</label>
                <input type="text" class="form-control" v-model="companyForm.name" required>
              </div>
              <div class="mb-3">
                <label class="form-label">Address *</label>
                <input type="text" class="form-control" v-model="companyForm.address" required>
              </div>
              <div class="row">
                <div class="col-md-6 mb-3">
                  <label class="form-label">City *</label>
                  <input type="text" class="form-control" v-model="companyForm.city" required>
                </div>
                <div class="col-md-3 mb-3">
                  <label class="form-label">State *</label>
                  <input type="text" class="form-control" v-model="companyForm.state" maxlength="2" required>
                </div>
                <div class="col-md-3 mb-3">
                  <label class="form-label">ZIP *</label>
                  <input type="text" class="form-control" v-model="companyForm.zip" required>
                </div>
              </div>
            </form>
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-secondary" @click="closeCompanyModal">Cancel</button>
            <button type="button" class="btn btn-primary" @click="saveCompany">
              {{ showEditCompanyModal ? 'Update' : 'Save' }} Company
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Add/Edit Account Modal -->
    <div class="modal fade" :class="{ show: showAddAccountModal || showEditAccountModal }" 
         :style="{ display: (showAddAccountModal || showEditAccountModal) ? 'block' : 'none' }" 
         tabindex="-1">
      <div class="modal-dialog modal-lg">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">{{ showEditAccountModal ? 'Edit' : 'Add' }} Bank Account</h5>
            <button type="button" class="btn-close" @click="closeAccountModal"></button>
          </div>
          <div class="modal-body">
            <form>
              <div class="mb-3">
                <label class="form-label">Account Name *</label>
                <input type="text" class="form-control" v-model="accountForm.name" placeholder="e.g., Operating Account" required>
              </div>
              <div class="row">
                <div class="col-md-6 mb-3">
                  <label class="form-label">Bank Name *</label>
                  <input type="text" class="form-control" v-model="accountForm.bankName" required>
                </div>
                <div class="col-md-6 mb-3">
                  <label class="form-label">Bank City</label>
                  <input type="text" class="form-control" v-model="accountForm.bankCity">
                </div>
              </div>
              <div class="row">
                <div class="col-md-6 mb-3">
                  <label class="form-label">Routing Number *</label>
                  <input type="text" class="form-control" v-model="accountForm.routingNumber" required>
                </div>
                <div class="col-md-6 mb-3">
                  <label class="form-label">Account Number *</label>
                  <input type="text" class="form-control" v-model="accountForm.accountNumber" required>
                </div>
              </div>
              <div class="mb-3">
                <label class="form-label">Signature</label>
                <input type="text" class="form-control" v-model="accountForm.signature">
              </div>
              <div class="mb-3">
                <label class="form-label">Default Check Layout</label>
                <select class="form-select" v-model="accountForm.defaultLayoutId">
                  <option value="">Original Layout</option>
                  <option v-for="layout in store.customLayouts.filter(l => l.id !== 'original')" :key="layout.id" :value="layout.id">
                    {{ layout.name }}
                  </option>
                </select>
              </div>
              <div class="mb-3">
                <label class="form-label">Background Color (for check identification)</label>
                <div class="color-picker-grid">
                  <div 
                    v-for="color in colorOptions" 
                    :key="color"
                    class="color-option"
                    :class="{ selected: accountForm.backgroundColor === color }"
                    :style="{ backgroundColor: color }"
                    @click="accountForm.backgroundColor = color"
                  >
                    <i v-if="accountForm.backgroundColor === color" class="bi bi-check-lg"></i>
                  </div>
                  <div 
                    class="color-option"
                    :class="{ selected: !accountForm.backgroundColor }"
                    style="background: white; border: 2px solid #dee2e6;"
                    @click="accountForm.backgroundColor = ''"
                  >
                    <span v-if="!accountForm.backgroundColor">None</span>
                  </div>
                </div>
              </div>
            </form>
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-secondary" @click="closeAccountModal">Cancel</button>
            <button type="button" class="btn btn-primary" @click="saveAccount">
              {{ showEditAccountModal ? 'Update' : 'Save' }} Account
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal backdrop -->
    <div class="modal-backdrop fade" :class="{ show: showAddCompanyModal || showEditCompanyModal || showAddAccountModal || showEditAccountModal }" 
         :style="{ display: (showAddCompanyModal || showEditCompanyModal || showAddAccountModal || showEditAccountModal) ? 'block' : 'none' }"></div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive } from 'vue'
import { useAppStore } from '../stores/app'
import type { Company, BankAccount } from '../stores/app'

const store = useAppStore()

// Modal visibility
const showAddCompanyModal = ref(false)
const showEditCompanyModal = ref(false)
const showAddAccountModal = ref(false)
const showEditAccountModal = ref(false)

// Forms
const companyForm = reactive({
  id: '',
  name: '',
  address: '',
  city: '',
  state: '',
  zip: ''
})

const accountForm = reactive({
  id: '',
  companyId: '',
  name: '',
  bankName: '',
  bankCity: '',
  routingNumber: '',
  accountNumber: '',
  signature: '',
  defaultLayoutId: '',
  backgroundColor: ''
})

// 16 color options for account background
const colorOptions = [
  '#ffebee', '#e3f2fd', '#e8f5e9', '#fff9c4',
  '#fce4ec', '#e1f5fe', '#f1f8e9', '#fff8e1',
  '#f3e5f5', '#e0f2f1', '#ede7f6', '#fbe9e7',
  '#e8eaf6', '#e0f7fa', '#f9fbe7', '#fff3e0'
]

// Helper functions
const getCompanyAccounts = (companyId: string) => {
  return store.bankAccounts.filter(account => account.companyId === companyId)
}

const getLayoutName = (layoutId?: string) => {
  if (!layoutId) return 'Original'
  const layout = store.customLayouts.find(l => l.id === layoutId)
  return layout ? layout.name : 'Original'
}

// Company CRUD
const editCompany = (company: Company) => {
  companyForm.id = company.id
  companyForm.name = company.name
  companyForm.address = company.address
  companyForm.city = company.city
  companyForm.state = company.state
  companyForm.zip = company.zip
  showEditCompanyModal.value = true
}

const deleteCompany = (companyId: string) => {
  if (!confirm('Are you sure you want to delete this company? All associated accounts will also be deleted.')) return
  
  // Delete all accounts for this company
  const accounts = getCompanyAccounts(companyId)
  accounts.forEach(account => {
    store.deleteBankAccount(account.id)
  })
  
  // Delete company
  store.deleteCompany(companyId)
}

const saveCompany = () => {
  if (!companyForm.name || !companyForm.address || !companyForm.city || !companyForm.state || !companyForm.zip) {
    alert('Please fill in all required fields')
    return
  }
  
  if (showEditCompanyModal.value) {
    // Update existing
    store.updateCompany(companyForm.id, {
      name: companyForm.name,
      address: companyForm.address,
      city: companyForm.city,
      state: companyForm.state,
      zip: companyForm.zip
    })
  } else {
    // Add new
    store.addCompany({
      id: `company_${Date.now()}`,
      name: companyForm.name,
      address: companyForm.address,
      city: companyForm.city,
      state: companyForm.state,
      zip: companyForm.zip
    })
  }
  
  closeCompanyModal()
}

const closeCompanyModal = () => {
  showAddCompanyModal.value = false
  showEditCompanyModal.value = false
  companyForm.id = ''
  companyForm.name = ''
  companyForm.address = ''
  companyForm.city = ''
  companyForm.state = ''
  companyForm.zip = ''
}

// Account CRUD
const showAddAccountModalForCompany = (companyId: string) => {
  accountForm.companyId = companyId
  showAddAccountModal.value = true
}

const editAccount = (account: BankAccount) => {
  accountForm.id = account.id
  accountForm.companyId = account.companyId
  accountForm.name = account.name
  accountForm.bankName = account.bankName
  accountForm.bankCity = account.bankCity || ''
  accountForm.routingNumber = account.routingNumber
  accountForm.accountNumber = account.accountNumber
  accountForm.signature = account.signature
  accountForm.defaultLayoutId = account.defaultLayoutId || ''
  accountForm.backgroundColor = account.backgroundColor || ''
  showEditAccountModal.value = true
}

const deleteAccount = (accountId: string) => {
  if (!confirm('Are you sure you want to delete this account?')) return
  store.deleteBankAccount(accountId)
}

const saveAccount = async () => {
  if (!accountForm.name || !accountForm.bankName || !accountForm.routingNumber || !accountForm.accountNumber) {
    alert('Please fill in all required fields')
    return
  }
  
  if (showEditAccountModal.value) {
    // Update existing
    await store.updateBankAccount(accountForm.id, {
      name: accountForm.name,
      bankName: accountForm.bankName,
      bankCity: accountForm.bankCity,
      routingNumber: accountForm.routingNumber,
      accountNumber: accountForm.accountNumber,
      signature: accountForm.signature,
      defaultLayoutId: accountForm.defaultLayoutId || undefined,
      backgroundColor: accountForm.backgroundColor || undefined
    })
  } else {
    // Add new
    await store.addBankAccount({
      id: `account_${Date.now()}`,
      companyId: accountForm.companyId,
      name: accountForm.name,
      bankName: accountForm.bankName,
      bankCity: accountForm.bankCity,
      routingNumber: accountForm.routingNumber,
      accountNumber: accountForm.accountNumber,
      signature: accountForm.signature,
      defaultLayoutId: accountForm.defaultLayoutId || undefined,
      backgroundColor: accountForm.backgroundColor || undefined
    })
  }
  
  closeAccountModal()
}

const closeAccountModal = () => {
  showAddAccountModal.value = false
  showEditAccountModal.value = false
  accountForm.id = ''
  accountForm.companyId = ''
  accountForm.name = ''
  accountForm.bankName = ''
  accountForm.bankCity = ''
  accountForm.routingNumber = ''
  accountForm.accountNumber = ''
  accountForm.signature = ''
  accountForm.defaultLayoutId = ''
  accountForm.backgroundColor = ''
}
</script>

<style scoped>
.company-section {
  margin-bottom: 2rem;
}

.company-card {
  border: 1px solid #dee2e6;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.company-header {
  background-color: #f8f9fa;
  border-bottom: 2px solid #dee2e6;
  padding: 1.25rem;
}

.company-header h4 {
  margin: 0;
  font-weight: 600;
  color: #212529;
}

.company-header small {
  color: #6c757d;
}

.account-card {
  border: 1px solid #dee2e6;
  transition: box-shadow 0.2s;
}

.account-card:hover {
  box-shadow: 0 2px 8px rgba(0,0,0,0.15);
}

.color-picker-grid {
  display: grid;
  grid-template-columns: repeat(8, 1fr);
  gap: 10px;
  margin-top: 10px;
}

.color-option {
  width: 100%;
  padding-top: 100%;
  position: relative;
  border-radius: 4px;
  cursor: pointer;
  border: 2px solid transparent;
  transition: all 0.2s;
}

.color-option:hover {
  transform: scale(1.1);
  box-shadow: 0 2px 8px rgba(0,0,0,0.2);
}

.color-option.selected {
  border-color: #0d6efd;
  box-shadow: 0 0 0 3px rgba(13, 110, 253, 0.25);
}

.color-option i {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  font-size: 24px;
  color: white;
  text-shadow: 0 0 3px rgba(0,0,0,0.5);
}

.color-option span {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  font-size: 10px;
  color: #6c757d;
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
