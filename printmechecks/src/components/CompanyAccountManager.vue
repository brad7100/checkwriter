<template>
  <div class="company-account-manager">
    <div class="row">
      <div class="col-md-6">
        <label class="form-label"><strong>Company</strong></label>
        <div class="input-group">
          <select class="form-select" v-model="store.selectedCompanyId" @change="onCompanyChange">
            <option value="">Select a company...</option>
            <option v-for="company in store.companies" :key="company.id" :value="company.id">
              {{ company.name }}
            </option>
          </select>
          <button class="btn btn-outline-secondary" type="button" @click="showAddCompanyModal = true" title="Add New Company">
            <i class="bi bi-plus"></i>
          </button>
        </div>
      </div>
      
      <div class="col-md-6">
        <label class="form-label"><strong>Bank Account</strong></label>
        <div class="input-group">
          <select class="form-select" v-model="store.selectedAccountId" @change="onAccountChange" :disabled="!store.selectedCompanyId">
            <option value="">Select an account...</option>
            <option v-for="account in store.accountsForSelectedCompany" :key="account.id" :value="account.id">
              {{ account.name }} ({{ account.bankName }})
            </option>
          </select>
          <button class="btn btn-outline-secondary" type="button" @click="showAddAccountModal = true" :disabled="!store.selectedCompanyId" title="Add New Account">
            <i class="bi bi-plus"></i>
          </button>
        </div>
      </div>
    </div>


    <!-- Add Company Modal -->
    <div class="modal fade" :class="{ show: showAddCompanyModal }" :style="{ display: showAddCompanyModal ? 'block' : 'none' }" tabindex="-1">
      <div class="modal-dialog">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Add New Company</h5>
            <button type="button" class="btn-close" @click="showAddCompanyModal = false"></button>
          </div>
          <div class="modal-body">
            <form>
              <div class="mb-3">
                <label class="form-label">Company Name</label>
                <input type="text" class="form-control" v-model="newCompany.name">
              </div>
              <div class="mb-3">
                <label class="form-label">Address</label>
                <input type="text" class="form-control" v-model="newCompany.address">
              </div>
              <div class="row">
                <div class="col-md-6 mb-3">
                  <label class="form-label">City</label>
                  <input type="text" class="form-control" v-model="newCompany.city">
                </div>
                <div class="col-md-3 mb-3">
                  <label class="form-label">State</label>
                  <input type="text" class="form-control" v-model="newCompany.state">
                </div>
                <div class="col-md-3 mb-3">
                  <label class="form-label">ZIP</label>
                  <input type="text" class="form-control" v-model="newCompany.zip">
                </div>
              </div>
            </form>
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-secondary" @click="showAddCompanyModal = false">Cancel</button>
            <button type="button" class="btn btn-primary" @click="saveCompany">Save Company</button>
          </div>
        </div>
      </div>
    </div>

    <!-- Add Account Modal -->
    <div class="modal fade" :class="{ show: showAddAccountModal }" :style="{ display: showAddAccountModal ? 'block' : 'none' }" tabindex="-1">
      <div class="modal-dialog">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Add New Bank Account</h5>
            <button type="button" class="btn-close" @click="showAddAccountModal = false"></button>
          </div>
          <div class="modal-body">
            <form>
              <div class="mb-3">
                <label class="form-label">Account Name</label>
                <input type="text" class="form-control" v-model="newAccount.name" placeholder="e.g., Operating Account">
              </div>
              <div class="mb-3">
                <label class="form-label">Bank Name</label>
                <input type="text" class="form-control" v-model="newAccount.bankName">
              </div>
              <div class="mb-3">
                <label class="form-label">Bank City</label>
                <input type="text" class="form-control" v-model="newAccount.bankCity">
              </div>
              <div class="mb-3">
                <label class="form-label">Routing Number</label>
                <input type="text" class="form-control" v-model="newAccount.routingNumber">
              </div>
              <div class="mb-3">
                <label class="form-label">Account Number</label>
                <input type="text" class="form-control" v-model="newAccount.accountNumber">
              </div>
              <div class="mb-3">
                <label class="form-label">Signature</label>
                <input type="text" class="form-control" v-model="newAccount.signature">
              </div>
            </form>
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-secondary" @click="showAddAccountModal = false">Cancel</button>
            <button type="button" class="btn btn-primary" @click="saveAccount">Save Account</button>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal backdrop -->
    <div class="modal-backdrop fade" :class="{ show: showAddCompanyModal || showAddAccountModal }" 
         :style="{ display: (showAddCompanyModal || showAddAccountModal) ? 'block' : 'none' }"></div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive } from 'vue'
import { useAppStore } from '../stores/app'

const store = useAppStore()

const showAddCompanyModal = ref(false)
const showAddAccountModal = ref(false)

const newCompany = reactive({
  name: '',
  address: '',
  city: '',
  state: '',
  zip: ''
})

const newAccount = reactive({
  name: '',
  bankName: '',
  bankCity: '',
  routingNumber: '',
  accountNumber: '',
  signature: ''
})

const onCompanyChange = () => {
  // Reset account selection when company changes
  store.selectedAccountId = ''
}

const onAccountChange = () => {
  // Account selection handled by store
}

const saveCompany = () => {
  if (!newCompany.name) {
    alert('Please enter a company name')
    return
  }
  
  store.addCompany({
    id: '', // Will be auto-generated by Supabase
    name: newCompany.name,
    address: newCompany.address,
    city: newCompany.city,
    state: newCompany.state,
    zip: newCompany.zip
  })
  
  // Reset form
  newCompany.name = ''
  newCompany.address = ''
  newCompany.city = ''
  newCompany.state = ''
  newCompany.zip = ''
  
  showAddCompanyModal.value = false
}

const saveAccount = () => {
  if (!newAccount.name || !newAccount.bankName || !newAccount.routingNumber || !newAccount.accountNumber) {
    alert('Please fill in all required fields')
    return
  }
  
  store.addBankAccount({
    id: '', // Will be auto-generated by Supabase
    companyId: store.selectedCompanyId,
    name: newAccount.name,
    bankName: newAccount.bankName,
    bankCity: newAccount.bankCity || '',
    routingNumber: newAccount.routingNumber,
    accountNumber: newAccount.accountNumber,
    signature: newAccount.signature
  })
  
  // Reset form
  newAccount.name = ''
  newAccount.bankName = ''
  newAccount.bankCity = ''
  newAccount.routingNumber = ''
  newAccount.accountNumber = ''
  newAccount.signature = ''
  
  showAddAccountModal.value = false
}
</script>

<style scoped>
.company-account-manager {
  position: relative;
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
