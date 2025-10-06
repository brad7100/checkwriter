<template>
  <div class="auth-view">
    <AuthLogin 
      v-if="authMode === 'login'"
      @switch-to-signup="authMode = 'signup'"
      @forgot-password="handleForgotPassword"
    />
    <AuthSignup 
      v-else-if="authMode === 'signup'"
      @switch-to-login="authMode = 'login'"
    />
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import AuthLogin from '@/components/AuthLogin.vue'
import AuthSignup from '@/components/AuthSignup.vue'
import { authService } from '@/lib/auth'

// Reactive state
const authMode = ref<'login' | 'signup'>('login')

// Methods
const handleForgotPassword = async (email: string) => {
  try {
    const { error } = await authService.resetPassword(email)
    if (error) {
      alert(`Error: ${error.message}`)
    } else {
      alert('Password reset email sent! Please check your inbox.')
    }
  } catch (err) {
    alert('An error occurred. Please try again.')
    console.error('Password reset error:', err)
  }
}
</script>

<style scoped>
.auth-view {
  min-height: 100vh;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}
</style>
