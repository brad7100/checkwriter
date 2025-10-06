<script setup lang="ts">
import { RouterLink, RouterView, useRouter } from 'vue-router'
import { onMounted, ref, computed } from 'vue'
import { useAppStore } from './stores/app'
import { migrateLocalStorageToSupabase } from './utils/migrateToSupabase'
import { authService } from './lib/auth'
import { supabase } from './lib/supabase'

const store = useAppStore()
const router = useRouter()
const showMigrationPrompt = ref(false)
const isMigrating = ref(false)
const checkWriterKey = ref(0)

// Simple authentication check
const isAuthenticated = ref(false)
const userEmail = ref('')

// Authentication methods
const handleSignOut = async () => {
  await supabase.auth.signOut()
  isAuthenticated.value = false
  userEmail.value = ''
  router.push('/auth')
}

// Check for QuickBooks OAuth callback
onMounted(async () => {
  // Check if user is logged in
  const { data: { session } } = await supabase.auth.getSession()
  if (session?.user) {
    isAuthenticated.value = true
    userEmail.value = session.user.email || ''
  }
  
  // Listen for auth changes
  supabase.auth.onAuthStateChange((event, session) => {
    isAuthenticated.value = !!session?.user
    userEmail.value = session?.user?.email || ''
  })
  const urlParams = new URLSearchParams(window.location.search)
  const qbConnected = urlParams.get('qb_connected')
  const companyId = urlParams.get('company_id')
  const companyName = urlParams.get('company_name')
  const realmId = urlParams.get('realmId')
  
  if (qbConnected === 'true' && companyId) {
    // Update company with QB connection info
    const company = store.companies.find(c => c.id === companyId)
    if (company) {
      company.quickbooksConnected = true
      company.quickbooksRealmId = realmId || undefined
      company.quickbooksCompanyName = companyName || undefined
      company.quickbooksLastSync = new Date().toISOString()
      store.saveData()
      
      alert(`Successfully connected to QuickBooks: ${companyName || 'Company'}`)
    }
    
    // Clean up URL
    window.history.replaceState({}, document.title, window.location.pathname)
  }

  // Check if there's localStorage data and Supabase is empty
  await store.loadData
  const hasLocalData = localStorage.getItem('companies') || localStorage.getItem('bankAccounts') || localStorage.getItem('customLayouts')
  const hasSupabaseData = store.companies.length > 0 || store.bankAccounts.length > 0
  
  if (hasLocalData && !hasSupabaseData && !localStorage.getItem('migrationCompleted')) {
    showMigrationPrompt.value = true
  }
})

const migrateData = async () => {
  isMigrating.value = true
  try {
    const success = await migrateLocalStorageToSupabase()
    if (success) {
      localStorage.setItem('migrationCompleted', 'true')
      alert('Migration completed successfully! Reloading data...')
      await store.loadData()
      showMigrationPrompt.value = false
    } else {
      alert('Migration failed. Please check the console for errors.')
    }
  } catch (error) {
    console.error('Migration error:', error)
    alert('Migration failed. Please try again or contact support.')
  } finally {
    isMigrating.value = false
  }
}

const skipMigration = () => {
  if (confirm('Are you sure? Your localStorage data will not be transferred to Supabase.')) {
    localStorage.setItem('migrationCompleted', 'skipped')
    showMigrationPrompt.value = false
  }
}

const createNewCheck = () => {
  // Clear any existing check data
  store.check = null
  
  // Force CheckPrinter component to re-render with new check
  checkWriterKey.value++
  
  // Navigate to home page (Check Writer)
  router.push('/')
}
</script>

<template>
    <!-- Loading Screen -->
    <div v-if="store.isLoading" class="loading-screen">
      <div class="loading-content">
        <img src="/mycheckprinter.png" alt="My Check Printer" style="max-width: 300px; height: auto; margin-bottom: 20px;" />
        <div class="spinner-border text-primary" role="status">
          <span class="visually-hidden">Loading...</span>
        </div>
        <p class="mt-3">Loading data from database...</p>
      </div>
    </div>

    <!-- Migration Prompt -->
    <div v-if="showMigrationPrompt && !store.isLoading" class="migration-modal">
      <div class="migration-content">
        <h3><i class="bi bi-database-up"></i> Migrate Data to Supabase</h3>
        <p>We detected data in your browser's local storage. Would you like to move it to the cloud database?</p>
        <div class="migration-benefits">
          <ul>
            <li><i class="bi bi-check-circle-fill text-success"></i> Access from any device</li>
            <li><i class="bi bi-check-circle-fill text-success"></i> Automatic backups</li>
            <li><i class="bi bi-check-circle-fill text-success"></i> Never lose your data</li>
          </ul>
        </div>
        <div class="migration-actions">
          <button class="btn btn-primary btn-lg" @click="migrateData" :disabled="isMigrating">
            <span v-if="isMigrating" class="spinner-border spinner-border-sm me-2"></span>
            {{ isMigrating ? 'Migrating...' : 'Migrate Now' }}
          </button>
          <button class="btn btn-outline-secondary" @click="skipMigration" :disabled="isMigrating">
            Skip
          </button>
        </div>
      </div>
    </div>

    <!-- Authentication Required -->
    <div v-else-if="!store.isLoading && !isAuthenticated">
      <div class="auth-redirect">
        <div class="auth-redirect-content">
          <img src="/mycheckprinter.png" alt="My Check Printer" style="max-width: 200px; height: auto; margin-bottom: 20px;" />
          <h3>Authentication Required</h3>
          <p>Please sign in to access CheckWriter</p>
          <button class="btn btn-primary btn-lg" @click="router.push('/auth')">
            <i class="bi bi-box-arrow-in-right"></i> Sign In
          </button>
        </div>
      </div>
    </div>

    <!-- Main App -->
    <div v-else-if="!store.isLoading && isAuthenticated">
      <div class="container">
          <div style="padding-bottom: 20px; padding-top: 20px; text-align: center;">
              <img src="/mycheckprinter.png" alt="My Check Printer" style="max-width: 300px; height: auto;" />
          </div>
          
          <div class="d-flex justify-content-between align-items-center mb-3">
              <div class="user-info">
                  <span class="text-muted">Welcome, {{ userEmail }}</span>
              </div>
              <div class="d-flex gap-2">
                  <button class="btn btn-success" @click="createNewCheck">
                      <i class="bi bi-plus-circle"></i> New Check
                  </button>
                  <button class="btn btn-outline-secondary" @click="handleSignOut">
                      <i class="bi bi-box-arrow-right"></i> Sign Out
                  </button>
              </div>
          </div>
          
          <ul class="nav nav-tabs">
              <li class="nav-item">
                  <RouterLink to="/" class="nav-link" :class="{'active': $route.path == '/'}">Check Writer</RouterLink>
              </li>
              <li class="nav-item">
                  <RouterLink to="/history" class="nav-link" :class="{'active': $route.path == '/history'}">History</RouterLink>
              </li>
              <li class="nav-item">
                  <RouterLink to="/manage" class="nav-link" :class="{'active': $route.path == '/manage'}">Manage</RouterLink>
              </li>
              <li class="nav-item">
                  <RouterLink to="/layouts" class="nav-link" :class="{'active': $route.path == '/layouts'}">Layout Editor</RouterLink>
              </li>
          </ul>
        <nav>
        </nav>
      </div>

      <div class="container">
        <RouterView :key="checkWriterKey" />
      </div>
    </div>
</template>

<style scoped>
.loading-screen {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100vh;
  background-color: #f8f9fa;
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 9999;
}

.loading-content {
  text-align: center;
}

.migration-modal {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100vh;
  background-color: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 10000;
}

.migration-content {
  background: white;
  padding: 40px;
  border-radius: 12px;
  max-width: 500px;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.3);
  text-align: center;
}

.migration-content h3 {
  margin-bottom: 20px;
  color: #0d6efd;
}

.migration-benefits {
  margin: 30px 0;
  text-align: left;
}

.migration-benefits ul {
  list-style: none;
  padding: 0;
}

.migration-benefits li {
  padding: 8px 0;
  font-size: 16px;
}

.migration-actions {
  display: flex;
  gap: 15px;
  justify-content: center;
  margin-top: 30px;
}

nav {
  width: 100%;
  font-size: 12px;
  text-align: center;
  margin-top: 2rem;
}

nav a.router-link-exact-active {
  color: var(--color-text);
}

nav a.router-link-exact-active:hover {
  background-color: transparent;
}

nav a {
  display: inline-block;
  padding: 0 1rem;
  border-left: 1px solid var(--color-border);
}

nav a:first-of-type {
  border: 0;
}

.auth-redirect {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}

.auth-redirect-content {
  background: white;
  padding: 40px;
  border-radius: 12px;
  box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
  text-align: center;
  max-width: 400px;
}

.auth-redirect-content h3 {
  color: #2d3748;
  margin-bottom: 10px;
}

.auth-redirect-content p {
  color: #718096;
  margin-bottom: 30px;
}

.user-info {
  font-size: 14px;
}

</style>
