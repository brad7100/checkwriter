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
      path: '/',
      name: 'home',
      component: HomeView,
      meta: { requiresAuth: true }
    },
    {
      path: '/history',
      name: 'history',
      component: () => import('../views/HistoryView.vue'),
      meta: { requiresAuth: true }
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
    },
    {
      path: '/approvals',
      name: 'approvals',
      component: () => import('../views/ApprovalQueueView.vue'),
      meta: { requiresAuth: true, requiresApprover: true }
    }
  ]
})

// Navigation guard: require auth, redirect invite users to set password, admin-only routes
router.beforeEach((to, from, next) => {
  const store = useAppStore()
  const isSetPassword = to.name === 'set-password'

  if (to.meta.requiresAuth) {
    if (store.userProfile?.must_set_password && !isSetPassword) {
      next({ name: 'set-password' })
      return
    }
    if (isSetPassword && !store.userProfile?.must_set_password) {
      next({ path: '/' })
      return
    }
  }
  if (to.meta.requiresAdmin) {
    if (!store.userProfile) {
      next({ path: '/' })
      return
    }
    if (store.userProfile.role !== 'admin') {
      next({ path: '/' })
      return
    }
  }
  if (to.meta.requiresApprover) {
    if (!store.userProfile) {
      next({ path: '/' })
      return
    }
    if (!['admin', 'approver'].includes(store.userProfile.role)) {
      next({ path: '/' })
      return
    }
  }
  next()
})

export default router
