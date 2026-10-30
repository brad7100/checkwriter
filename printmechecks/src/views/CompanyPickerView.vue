<template>
  <div class="company-picker-container">
    <div class="picker-header">
      <img src="/mycheckprinter.png" alt="My Check Printer" class="logo" />
      <h1>Select a Company</h1>
      <p class="subtitle">Choose which business you're working with</p>
    </div>

    <div class="companies-grid">
      <div
        v-for="company in store.visibleCompanies"
        :key="company.id"
        class="company-card"
        @click="selectCompany(company.id)"
      >
        <div class="company-logo-container">
          <img
            v-if="company.logo_url"
            :src="getLogoUrl(company.logo_url)"
            :alt="company.name"
            class="company-logo"
          />
          <div v-else class="company-logo-placeholder">
            {{ getInitials(company.name) }}
          </div>
        </div>
        <div class="company-info">
          <h3 class="company-name">{{ company.name }}</h3>
          <p class="company-location">{{ company.city }}, {{ company.state }}</p>
        </div>
      </div>

      <!-- Add Company Card (Admin Only) -->
      <div
        v-if="store.isAdmin"
        class="company-card add-company-card"
        @click="showAddCompanyModal = true"
      >
        <div class="add-company-content">
          <i class="bi bi-plus-circle"></i>
          <span>Add New Company</span>
        </div>
      </div>
    </div>

    <!-- Empty State -->
    <div v-if="store.visibleCompanies.length === 0" class="empty-state">
      <i class="bi bi-building"></i>
      <h3>No Companies Available</h3>
      <p v-if="!store.isAdmin">Please contact your administrator to get access to a company.</p>
      <button v-if="store.isAdmin" class="btn btn-primary" @click="showAddCompanyModal = true">
        <i class="bi bi-plus-circle"></i> Add Your First Company
      </button>
    </div>

    <!-- Add Company Modal -->
    <div class="modal fade" :class="{ show: showAddCompanyModal }" :style="{ display: showAddCompanyModal ? 'block' : 'none' }" tabindex="-1">
      <div class="modal-dialog">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Add New Company</h5>
            <button type="button" class="btn-close" @click="closeAddCompanyModal"></button>
          </div>
          <div class="modal-body">
            <form @submit.prevent="saveCompany">
              <div class="mb-3">
                <label class="form-label">Company Name *</label>
                <input type="text" class="form-control" v-model="newCompany.name" required>
              </div>
              
              <div class="mb-3">
                <label class="form-label">Company Logo</label>
                <input type="file" class="form-control" @change="handleLogoUpload" accept="image/*">
                <small class="form-text text-muted">Upload a logo image (PNG, JPG, or SVG recommended)</small>
                <div v-if="logoPreview" class="logo-preview mt-2">
                  <img :src="logoPreview" alt="Logo preview" />
                </div>
              </div>

              <div class="mb-3">
                <label class="form-label">Address *</label>
                <input type="text" class="form-control" v-model="newCompany.address" required>
              </div>

              <div class="row">
                <div class="col-md-6 mb-3">
                  <label class="form-label">City *</label>
                  <input type="text" class="form-control" v-model="newCompany.city" required>
                </div>
                <div class="col-md-3 mb-3">
                  <label class="form-label">State *</label>
                  <input type="text" class="form-control" v-model="newCompany.state" maxlength="2" required>
                </div>
                <div class="col-md-3 mb-3">
                  <label class="form-label">ZIP *</label>
                  <input type="text" class="form-control" v-model="newCompany.zip" required>
                </div>
              </div>
            </form>
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-secondary" @click="closeAddCompanyModal">Cancel</button>
            <button type="button" class="btn btn-primary" @click="saveCompany" :disabled="isSaving">
              <span v-if="isSaving" class="spinner-border spinner-border-sm me-2"></span>
              {{ isSaving ? 'Saving...' : 'Save Company' }}
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal Backdrop -->
    <div class="modal-backdrop fade" :class="{ show: showAddCompanyModal }" 
         :style="{ display: showAddCompanyModal ? 'block' : 'none' }"></div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { useAppStore } from '../stores/app'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'

const store = useAppStore()
const router = useRouter()

const showAddCompanyModal = ref(false)
const isSaving = ref(false)
const logoFile = ref<File | null>(null)
const logoPreview = ref<string>('')

const newCompany = reactive({
  name: '',
  address: '',
  city: '',
  state: '',
  zip: ''
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

const selectCompany = (companyId: string) => {
  store.selectedCompanyId = companyId
  store.selectedAccountId = '' // Reset account selection
  store.saveData()
  router.push('/account-picker')
}

const handleLogoUpload = (event: Event) => {
  const target = event.target as HTMLInputElement
  if (target.files && target.files[0]) {
    logoFile.value = target.files[0]
    
    // Create preview
    const reader = new FileReader()
    reader.onload = (e) => {
      logoPreview.value = e.target?.result as string
    }
    reader.readAsDataURL(logoFile.value)
  }
}

const uploadLogo = async (companyId: string): Promise<string | null> => {
  if (!logoFile.value) return null

  try {
    const fileExt = logoFile.value.name.split('.').pop()
    const fileName = `${companyId}.${fileExt}`
    const filePath = `${fileName}`

    const { error: uploadError } = await supabase.storage
      .from('company-logos')
      .upload(filePath, logoFile.value, {
        cacheControl: '3600',
        upsert: true
      })

    if (uploadError) {
      console.error('Error uploading logo:', uploadError)
      return null
    }

    return filePath
  } catch (error) {
    console.error('Error uploading logo:', error)
    return null
  }
}

const saveCompany = async () => {
  if (!newCompany.name || !newCompany.address || !newCompany.city || !newCompany.state || !newCompany.zip) {
    alert('Please fill in all required fields')
    return
  }

  isSaving.value = true

  try {
    // Insert company first
    const { data, error } = await supabase
      .from('companies')
      .insert([{
        name: newCompany.name,
        address: newCompany.address,
        city: newCompany.city,
        state: newCompany.state,
        zip: newCompany.zip
      }])
      .select()
      .single()

    if (error) throw error

    // Upload logo if provided
    let logoPath = null
    if (logoFile.value) {
      logoPath = await uploadLogo(data.id)
      
      // Update company with logo path
      if (logoPath) {
        await supabase
          .from('companies')
          .update({ logo_url: logoPath })
          .eq('id', data.id)
      }
    }

    // Add to local state
    store.companies.push({
      id: data.id,
      name: data.name,
      address: data.address,
      city: data.city,
      state: data.state,
      zip: data.zip,
      logo_url: logoPath || undefined,
      quickbooksRealmId: data.quickbooks_realm_id,
      quickbooksConnected: data.quickbooks_connected,
      quickbooksCompanyName: data.quickbooks_company_name,
      quickbooksLastSync: data.quickbooks_last_sync
    })

    // Reset form
    closeAddCompanyModal()
    alert('Company added successfully!')
  } catch (error: any) {
    console.error('Error adding company:', error)
    alert(`Failed to add company: ${error.message || 'Please check your connection.'}`)
  } finally {
    isSaving.value = false
  }
}

const closeAddCompanyModal = () => {
  showAddCompanyModal.value = false
  newCompany.name = ''
  newCompany.address = ''
  newCompany.city = ''
  newCompany.state = ''
  newCompany.zip = ''
  logoFile.value = null
  logoPreview.value = ''
}

onMounted(() => {
  // If a company is already selected, the user might have clicked "Change Company"
  // Clear selections to force reselection
  store.selectedCompanyId = ''
  store.selectedAccountId = ''
  
  // If user only has access to one company, auto-select it and move to account picker
  if (store.visibleCompanies.length === 1) {
    const onlyCompany = store.visibleCompanies[0]
    store.selectedCompanyId = onlyCompany.id
    store.saveData()
    router.push('/account-picker')
  }
})
</script>

<style scoped>
.company-picker-container {
  min-height: 100vh;
  background: #ffffff;
  padding: 40px 20px;
}

.picker-header {
  text-align: center;
  color: #2d3748;
  margin-bottom: 40px;
}

.picker-header .logo {
  max-width: 250px;
  height: auto;
  margin-bottom: 20px;
  padding: 15px;
  border-radius: 12px;
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

.companies-grid {
  max-width: 1200px;
  margin: 0 auto;
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 24px;
  padding: 0 20px;
}

.company-card {
  background: white;
  border-radius: 16px;
  padding: 32px 24px;
  cursor: pointer;
  transition: all 0.3s ease;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
}

.company-card:hover {
  transform: translateY(-8px);
  box-shadow: 0 12px 24px rgba(0, 0, 0, 0.15);
}

.company-logo-container {
  width: 120px;
  height: 120px;
  margin-bottom: 20px;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
}

.company-logo {
  max-width: 100%;
  max-height: 100%;
  object-fit: contain;
  border-radius: 8px;
}

.company-logo-placeholder {
  width: 120px;
  height: 120px;
  border-radius: 12px;
  background: #f7fafc;
  border: 2px solid #e2e8f0;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 2.5rem;
  font-weight: 700;
  color: #4a5568;
  text-transform: uppercase;
}

.company-info {
  width: 100%;
}

.company-name {
  font-size: 1.3rem;
  font-weight: 600;
  margin-bottom: 8px;
  color: #2d3748;
}

.company-location {
  font-size: 0.95rem;
  color: #718096;
  margin: 0;
}

.add-company-card {
  border: 2px dashed #cbd5e0;
  background: rgba(255, 255, 255, 0.6);
  justify-content: center;
}

.add-company-card:hover {
  border-color: #0d6efd;
  background: white;
}

.add-company-content {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
  color: #4a5568;
  font-size: 1rem;
  font-weight: 600;
}

.add-company-content i {
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

.logo-preview {
  display: flex;
  justify-content: center;
  padding: 10px;
  background: #f7fafc;
  border-radius: 8px;
}

.logo-preview img {
  max-width: 150px;
  max-height: 150px;
  object-fit: contain;
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
