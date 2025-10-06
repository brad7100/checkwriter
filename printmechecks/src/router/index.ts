import { createRouter, createWebHistory } from 'vue-router'
import HomeView from '../views/HomeView.vue'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/',
      name: 'home',
      component: HomeView
    },
    {
      path: '/history',
      name: 'history',
      component: () => import('../views/HistoryView.vue')
    },
    {
      path: '/manage',
      name: 'manage',
      component: () => import('../views/ManageView.vue')
    },
    {
      path: '/layouts',
      name: 'layouts',
      component: () => import('../components/CheckLayoutCreator.vue')
    },
    {
      path: '/layout-editor/:id',
      name: 'layout-editor',
      component: () => import('../views/LayoutEditorView.vue')
    }
  ]
})

export default router
