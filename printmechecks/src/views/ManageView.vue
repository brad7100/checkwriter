<template>
  <div>
    <main>
      <div class="container">
        <div class="d-flex justify-content-between align-items-center mb-4">
          <h2>Manage Companies & Accounts</h2>
          <div class="d-flex gap-2">
            <button class="btn btn-primary" @click="showAddCompanyModal = true">
              <i class="bi bi-plus-lg"></i> Add Company
            </button>
          </div>
        </div>

        <!-- Invite user / Password reset (admin only) -->
        <div class="card mb-4 border-primary">
          <div class="card-body">
            <h5 class="card-title"><i class="bi bi-people me-2"></i>Users</h5>
            <p class="text-muted small mb-0">Only admins can add users. New users receive an email to set their password. After they sign in, assign them to bank accounts below.</p>
            <div class="d-flex gap-2 align-items-end mt-3 flex-wrap">
              <button class="btn btn-outline-primary" @click="showInviteUserModal = true">
                <i class="bi bi-person-plus"></i> Invite user
              </button>
              <div class="d-flex gap-2 align-items-center">
                <label class="form-label mb-0 small text-muted">Send password reset:</label>
                <input type="email" class="form-control form-control-sm" style="width: 200px;" v-model="resetPasswordEmail" placeholder="user@example.com" />
                <button class="btn btn-outline-secondary btn-sm" @click="sendPasswordReset" :disabled="resetPasswordLoading || !resetPasswordEmail.trim()">
                  <span v-if="resetPasswordLoading" class="spinner-border spinner-border-sm me-1"></span>
                  Send
                </button>
              </div>
            </div>
            <div v-if="resetPasswordMessage" class="small mt-2" :class="resetPasswordError ? 'text-danger' : 'text-success'">{{ resetPasswordMessage }}</div>
          </div>
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
                          <!-- User access (admin only) -->
                          <div class="mt-3 pt-3 border-top">
                            <strong class="small text-muted"><i class="bi bi-person-check me-1"></i>Users with access</strong>
                            <ul v-if="getUsersForAccount(account.id).length > 0" class="list-unstyled small mb-2 mt-1">
                              <li v-for="u in getUsersForAccount(account.id)" :key="u.id" class="d-flex align-items-center justify-content-between py-1">
                                <span>{{ u.email }} <span v-if="u.role === 'admin'" class="badge bg-primary ms-1">Admin</span></span>
                                <button type="button" class="btn btn-outline-danger btn-sm py-0 px-1" @click="removeUserFromAccount(u.linkId)" title="Remove access">×</button>
                              </li>
                            </ul>
                            <p v-else class="small text-muted mb-1">No users assigned (admin always has access)</p>
                            <button type="button" class="btn btn-outline-secondary btn-sm" @click="openAddUserModal(account)">
                              <i class="bi bi-person-plus"></i> Add user
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

    <!-- Invite user modal -->
    <div class="modal fade" :class="{ show: showInviteUserModal }" :style="{ display: showInviteUserModal ? 'block' : 'none' }" tabindex="-1">
      <div class="modal-dialog">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Invite user</h5>
            <button type="button" class="btn-close" @click="closeInviteUserModal"></button>
          </div>
          <div class="modal-body">
            <p class="small text-muted">They will receive an email to set their password. After they sign in, assign them to bank accounts below.</p>
            <label class="form-label">Email</label>
            <input type="email" class="form-control" v-model="inviteUserEmail" placeholder="user@example.com" :disabled="inviteUserLoading" />
            <div v-if="inviteUserError" class="alert alert-danger mt-2 mb-0">{{ inviteUserError }}</div>
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-secondary" @click="closeInviteUserModal">Cancel</button>
            <button type="button" class="btn btn-primary" @click="sendInvite" :disabled="inviteUserLoading || !inviteUserEmail.trim()">
              <span v-if="inviteUserLoading" class="spinner-border spinner-border-sm me-2"></span>
              Send invite
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Add user to account modal -->
    <div class="modal fade" :class="{ show: showAddUserModal }" :style="{ display: showAddUserModal ? 'block' : 'none' }" tabindex="-1">
      <div class="modal-dialog">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Add user to account</h5>
            <button type="button" class="btn-close" @click="closeAddUserModal"></button>
          </div>
          <div class="modal-body">
            <p class="small text-muted">Account: <strong>{{ addUserTargetAccount?.name }}</strong></p>
            <label class="form-label">User</label>
            <select class="form-select" v-model="addUserSelectedProfileId">
              <option value="">Select a user...</option>
              <option v-for="p in availableProfilesForAccount" :key="p.id" :value="p.id">{{ p.email }} ({{ p.role }})</option>
            </select>
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-secondary" @click="closeAddUserModal">Cancel</button>
            <button type="button" class="btn btn-primary" @click="saveAddUserToAccount" :disabled="!addUserSelectedProfileId">Add</button>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal backdrop -->
    <div class="modal-backdrop fade" :class="{ show: showAddCompanyModal || showEditCompanyModal || showAddAccountModal || showEditAccountModal || showAddUserModal || showInviteUserModal }"
         :style="{ display: (showAddCompanyModal || showEditCompanyModal || showAddAccountModal || showEditAccountModal || showAddUserModal || showInviteUserModal) ? 'block' : 'none' }"></div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue'
import { useAppStore } from '../stores/app'
import { supabase } from '../lib/supabase'
import type { Company, BankAccount } from '../stores/app'

const store = useAppStore()

// User access (profiles + account_users)
const profiles = ref<{ id: string; email: string; role: string }[]>([])
const accountUsers = ref<{ id: string; user_id: string; bank_account_id: string }[]>([])
const showAddUserModal = ref(false)
const addUserTargetAccount = ref<BankAccount | null>(null)
const addUserSelectedProfileId = ref('')

// Invite user (admin-only, no public signup)
const showInviteUserModal = ref(false)
const inviteUserEmail = ref('')
const inviteUserLoading = ref(false)
const inviteUserError = ref('')

// Send password reset to existing user
const resetPasswordEmail = ref('')
const resetPasswordLoading = ref(false)
const resetPasswordMessage = ref('')
const resetPasswordError = ref(false)

const closeInviteUserModal = () => {
  showInviteUserModal.value = false
  inviteUserEmail.value = ''
  inviteUserError.value = ''
}

const sendPasswordReset = async () => {
  const email = resetPasswordEmail.value.trim()
  if (!email) return
  resetPasswordMessage.value = ''
  resetPasswordError.value = false
  resetPasswordLoading.value = true
  try {
    const { data, error } = await supabase.functions.invoke('invite-user', {
      body: { email, action: 'reset' },
    })
    if (error) {
      resetPasswordMessage.value = error.message || 'Failed to send reset'
      resetPasswordError.value = true
      return
    }
    const errMsg = (data && typeof data === 'object' && 'error' in data) ? (data as { error: string }).error : null
    if (errMsg) {
      resetPasswordMessage.value = errMsg
      resetPasswordError.value = true
      return
    }
    resetPasswordMessage.value = (data && typeof data === 'object' && 'message' in data) ? (data as { message: string }).message : 'Password reset email sent.'
    resetPasswordEmail.value = ''
  } catch (e) {
    resetPasswordMessage.value = (e instanceof Error ? e.message : 'Request failed') + '. Is the invite-user function deployed?'
    resetPasswordError.value = true
  } finally {
    resetPasswordLoading.value = false
  }
}

const sendInvite = async () => {
  const email = inviteUserEmail.value.trim()
  if (!email) return
  inviteUserError.value = ''
  inviteUserLoading.value = true
  try {
    const { data, error } = await supabase.functions.invoke('invite-user', {
      body: { email },
    })
    if (error) {
      inviteUserError.value = error.message || 'Invite failed'
      return
    }
    const errMsg = (data && typeof data === 'object' && 'error' in data) ? (data as { error: string }).error : null
    if (errMsg) {
      inviteUserError.value = errMsg
      return
    }
    alert((data && typeof data === 'object' && 'message' in data) ? (data as { message: string }).message : 'Invitation sent.')
    closeInviteUserModal()
    await loadProfiles()
  } catch (e) {
    inviteUserError.value = (e instanceof Error ? e.message : 'Request failed') +
      '. If the invite-user function is not deployed, run: supabase functions deploy invite-user'
  } finally {
    inviteUserLoading.value = false
  }
}

const getUsersForAccount = (accountId: string) => {
  const links = accountUsers.value.filter(au => au.bank_account_id === accountId)
  return links.map(au => {
    const p = profiles.value.find(pr => pr.id === au.user_id)
    return { id: au.user_id, linkId: au.id, email: p?.email ?? 'Unknown', role: p?.role ?? 'user' }
  })
}

const availableProfilesForAccount = computed(() => {
  if (!addUserTargetAccount.value) return []
  const already = accountUsers.value.filter(au => au.bank_account_id === addUserTargetAccount.value!.id).map(au => au.user_id)
  return profiles.value.filter(p => !already.includes(p.id))
})

const openAddUserModal = (account: BankAccount) => {
  addUserTargetAccount.value = account
  addUserSelectedProfileId.value = ''
  showAddUserModal.value = true
}

const closeAddUserModal = () => {
  showAddUserModal.value = false
  addUserTargetAccount.value = null
  addUserSelectedProfileId.value = ''
}

const saveAddUserToAccount = async () => {
  if (!addUserTargetAccount.value || !addUserSelectedProfileId.value) return
  const { error } = await supabase.from('account_users').insert([{
    user_id: addUserSelectedProfileId.value,
    bank_account_id: addUserTargetAccount.value.id
  }])
  if (error) {
    alert('Could not add user: ' + error.message)
    return
  }
  await loadAccountUsers()
  closeAddUserModal()
}

const removeUserFromAccount = async (linkId: string) => {
  if (!confirm('Remove this user’s access to this account?')) return
  const { error } = await supabase.from('account_users').delete().eq('id', linkId)
  if (error) {
    alert('Could not remove: ' + error.message)
    return
  }
  await loadAccountUsers()
}

async function loadAccountUsers() {
  const { data } = await supabase.from('account_users').select('id, user_id, bank_account_id')
  accountUsers.value = data ?? []
}

async function loadProfiles() {
  const { data } = await supabase.from('profiles').select('id, email, role')
  profiles.value = (data ?? []) as { id: string; email: string; role: string }[]
}

onMounted(async () => {
  if (store.isAdmin) {
    await loadProfiles()
    await loadAccountUsers()
  }
})

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
