import { createRouter, createWebHistory } from 'vue-router'
import HomeView from '../views/HomeView.vue'
import AuthView from '../views/AuthView.vue'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/auth',
      name: 'auth',
      component: AuthView
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
      meta: { requiresAuth: true }
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

// Navigation guard for authentication
router.beforeEach((to, from, next) => {
  // Check if route requires authentication
  if (to.meta.requiresAuth) {
    // Check if user is authenticated
    // For now, we'll let the App.vue handle the authentication check
    // This ensures the auth state is properly loaded before checking
    next()
  } else {
    next()
  }
})

export default router
