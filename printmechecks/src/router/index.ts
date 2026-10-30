import { createRouter, createWebHistory } from 'vue-router'
import HomeView from '../views/HomeView.vue'
import AuthView from '../views/AuthView.vue'
import { useAppStore } from '../stores/app'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/auth',
      name: 'auth',
      component: AuthView
    },
    {
      path: '/set-password',
      name: 'set-password',
      component: () => import('../views/SetPasswordView.vue'),
      meta: { requiresAuth: true }
    },
    {
      path: '/company-picker',
      name: 'company-picker',
      component: () => import('../views/CompanyPickerView.vue'),
      meta: { requiresAuth: true }
    },
    {
      path: '/account-picker',
      name: 'account-picker',
      component: () => import('../views/AccountPickerView.vue'),
      meta: { requiresAuth: true, requiresCompany: true }
    },
    {
      path: '/',
      name: 'home',
      component: HomeView,
      meta: { requiresAuth: true, requiresAccount: true }
    },
    {
      path: '/history',
      name: 'history',
      component: () => import('../views/HistoryView.vue'),
      meta: { requiresAuth: true, requiresAccount: true }
    },
    {
      path: '/manage',
      name: 'manage',
      component: () => import('../views/ManageView.vue'),
      meta: { requiresAuth: true, requiresAdmin: true }
    },
    {
      path: '/layouts',
      name: 'layouts',
      component: () => import('../components/CheckLayoutCreator.vue'),
      meta: { requiresAuth: true }
    },
    {
      path: '/layout-editor/:id',
      name: 'layout-editor',
      component: () => import('../views/LayoutEditorView.vue'),
      meta: { requiresAuth: true }
    }
  ]
})

// Navigation guard: require auth, redirect invite users to set password, admin-only routes, company/account selection
router.beforeEach((to, from, next) => {
  const store = useAppStore()
  const isSetPassword = to.name === 'set-password'
  const isCompanyPicker = to.name === 'company-picker'
  const isAccountPicker = to.name === 'account-picker'

  if (to.meta.requiresAuth) {
    if (store.userProfile?.must_set_password && !isSetPassword) {
      next({ name: 'set-password' })
      return
    }
    if (isSetPassword && !store.userProfile?.must_set_password) {
      next({ name: 'company-picker' })
      return
    }
  }
  
  // Check if company selection is required
  if (to.meta.requiresAccount || to.meta.requiresCompany) {
    if (!store.selectedCompanyId && !isCompanyPicker) {
      next({ name: 'company-picker' })
      return
    }
    
    if (to.meta.requiresAccount && !store.selectedAccountId && !isAccountPicker) {
      next({ name: 'account-picker' })
      return
    }
  }
  
  if (to.meta.requiresAdmin) {
    if (!store.userProfile) {
      next({ name: 'company-picker' })
      return
    }
    if (store.userProfile.role !== 'admin') {
      next({ name: 'company-picker' })
      return
    }
  }
  next()
})

export default router
