<template>
  <div class="set-password-page">
    <div class="set-password-card">
      <h2><i class="bi bi-lock me-2"></i>Set your password</h2>
      <p class="text-muted">You were invited to CheckWriter. Choose a password to secure your account.</p>
      <form @submit.prevent="submit" class="set-password-form">
        <div class="mb-3">
          <label class="form-label">New password</label>
          <input
            v-model="password"
            type="password"
            class="form-control"
            :class="{ 'is-invalid': errors.password }"
            placeholder="Enter password"
            required
            minlength="6"
            :disabled="loading"
          />
          <div v-if="errors.password" class="invalid-feedback">{{ errors.password }}</div>
        </div>
        <div class="mb-3">
          <label class="form-label">Confirm password</label>
          <input
            v-model="confirmPassword"
            type="password"
            class="form-control"
            :class="{ 'is-invalid': errors.confirmPassword }"
            placeholder="Confirm password"
            required
            :disabled="loading"
          />
          <div v-if="errors.confirmPassword" class="invalid-feedback">{{ errors.confirmPassword }}</div>
        </div>
        <div v-if="error" class="alert alert-danger">{{ error }}</div>
        <button type="submit" class="btn btn-primary w-100" :disabled="loading">
          <span v-if="loading" class="spinner-border spinner-border-sm me-2"></span>
          Set password
        </button>
      </form>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import { useAppStore } from '../stores/app'

const router = useRouter()
const store = useAppStore()

const password = ref('')
const confirmPassword = ref('')
const loading = ref(false)
const error = ref('')
const errors = reactive<{ password?: string; confirmPassword?: string }>({})

const submit = async () => {
  error.value = ''
  errors.password = ''
  errors.confirmPassword = ''

  if (password.value.length < 6) {
    errors.password = 'Password must be at least 6 characters'
    return
  }
  if (password.value !== confirmPassword.value) {
    errors.confirmPassword = 'Passwords do not match'
    return
  }

  loading.value = true
  try {
    const { error: updateError } = await supabase.auth.updateUser({ password: password.value })
    if (updateError) throw updateError
    await store.clearMustSetPassword()
    router.replace('/')
  } catch (e: unknown) {
    error.value = e instanceof Error ? e.message : 'Failed to set password'
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.set-password-page {
  max-width: 420px;
  margin: 60px auto;
  padding: 20px;
}
.set-password-card {
  background: #fff;
  border: 1px solid #dee2e6;
  border-radius: 12px;
  padding: 2rem;
  box-shadow: 0 2px 8px rgba(0,0,0,0.08);
}
.set-password-card h2 {
  margin-bottom: 0.5rem;
  font-weight: 600;
}
.set-password-form {
  margin-top: 1.5rem;
}
</style>
