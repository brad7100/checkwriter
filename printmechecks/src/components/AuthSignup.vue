<template>
  <div class="auth-container">
    <div class="auth-card">
      <div class="auth-header">
        <h2 class="auth-title">Create Account</h2>
        <p class="auth-subtitle">Sign up for CheckWriter</p>
      </div>

      <form @submit.prevent="handleSignUp" class="auth-form">
        <div class="form-group">
          <label for="fullName" class="form-label">Full Name</label>
          <input
            id="fullName"
            v-model="form.fullName"
            type="text"
            class="form-control"
            :class="{ 'is-invalid': errors.fullName }"
            placeholder="Enter your full name"
            required
            :disabled="loading"
          />
          <div v-if="errors.fullName" class="invalid-feedback">
            {{ errors.fullName }}
          </div>
        </div>

        <div class="form-group">
          <label for="email" class="form-label">Email Address</label>
          <input
            id="email"
            v-model="form.email"
            type="email"
            class="form-control"
            :class="{ 'is-invalid': errors.email }"
            placeholder="Enter your email"
            required
            :disabled="loading"
          />
          <div v-if="errors.email" class="invalid-feedback">
            {{ errors.email }}
          </div>
        </div>

        <div class="form-group">
          <label for="password" class="form-label">Password</label>
          <div class="password-input">
            <input
              id="password"
              v-model="form.password"
              :type="showPassword ? 'text' : 'password'"
              class="form-control"
              :class="{ 'is-invalid': errors.password }"
              placeholder="Create a password"
              required
              :disabled="loading"
            />
            <button
              type="button"
              class="password-toggle"
              @click="showPassword = !showPassword"
              :disabled="loading"
            >
              <i :class="showPassword ? 'bi bi-eye-slash' : 'bi bi-eye'"></i>
            </button>
          </div>
          <div v-if="errors.password" class="invalid-feedback">
            {{ errors.password }}
          </div>
        </div>

        <div class="form-group">
          <label for="confirmPassword" class="form-label">Confirm Password</label>
          <div class="password-input">
            <input
              id="confirmPassword"
              v-model="form.confirmPassword"
              :type="showConfirmPassword ? 'text' : 'password'"
              class="form-control"
              :class="{ 'is-invalid': errors.confirmPassword }"
              placeholder="Confirm your password"
              required
              :disabled="loading"
            />
            <button
              type="button"
              class="password-toggle"
              @click="showConfirmPassword = !showConfirmPassword"
              :disabled="loading"
            >
              <i :class="showConfirmPassword ? 'bi bi-eye-slash' : 'bi bi-eye'"></i>
            </button>
          </div>
          <div v-if="errors.confirmPassword" class="invalid-feedback">
            {{ errors.confirmPassword }}
          </div>
        </div>

        <div class="form-group">
          <div class="form-check">
            <input
              id="terms"
              v-model="form.acceptTerms"
              type="checkbox"
              class="form-check-input"
              :class="{ 'is-invalid': errors.acceptTerms }"
              required
              :disabled="loading"
            />
            <label for="terms" class="form-check-label">
              I agree to the <a href="#" class="terms-link">Terms of Service</a> and <a href="#" class="terms-link">Privacy Policy</a>
            </label>
          </div>
          <div v-if="errors.acceptTerms" class="invalid-feedback">
            {{ errors.acceptTerms }}
          </div>
        </div>

        <div v-if="error" class="alert alert-danger">
          <i class="bi bi-exclamation-triangle"></i>
          {{ error }}
        </div>

        <div v-if="success" class="alert alert-success">
          <i class="bi bi-check-circle"></i>
          {{ success }}
        </div>

        <button
          type="submit"
          class="btn btn-primary auth-button"
          :disabled="loading || !isFormValid"
        >
          <span v-if="loading" class="spinner-border spinner-border-sm me-2"></span>
          <i v-else class="bi bi-person-plus me-2"></i>
          {{ loading ? 'Creating Account...' : 'Create Account' }}
        </button>
      </form>

      <div class="auth-footer">
        <p class="auth-switch">
          Already have an account?
          <button
            type="button"
            class="auth-link"
            @click="$emit('switch-to-login')"
            :disabled="loading"
          >
            Sign in
          </button>
        </p>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, reactive } from 'vue'
import { authService, type SignUpData } from '@/lib/auth'

// Emits
const emit = defineEmits<{
  'switch-to-login': []
}>()

// Reactive state
const loading = ref(false)
const error = ref('')
const success = ref('')
const showPassword = ref(false)
const showConfirmPassword = ref(false)

const form = reactive<SignUpData & { confirmPassword: string; acceptTerms: boolean }>({
  fullName: '',
  email: '',
  password: '',
  confirmPassword: '',
  acceptTerms: false
})

const errors = reactive({
  fullName: '',
  email: '',
  password: '',
  confirmPassword: '',
  acceptTerms: ''
})

// Computed
const isFormValid = computed(() => {
  return form.fullName && 
         form.email && 
         form.password && 
         form.confirmPassword && 
         form.acceptTerms &&
         !errors.fullName && 
         !errors.email && 
         !errors.password && 
         !errors.confirmPassword && 
         !errors.acceptTerms
})

// Methods
const validateForm = () => {
  errors.fullName = ''
  errors.email = ''
  errors.password = ''
  errors.confirmPassword = ''
  errors.acceptTerms = ''

  if (!form.fullName.trim()) {
    errors.fullName = 'Full name is required'
  } else if (form.fullName.trim().length < 2) {
    errors.fullName = 'Full name must be at least 2 characters'
  }

  if (!form.email) {
    errors.email = 'Email is required'
  } else if (!/\S+@\S+\.\S+/.test(form.email)) {
    errors.email = 'Please enter a valid email address'
  }

  if (!form.password) {
    errors.password = 'Password is required'
  } else if (form.password.length < 6) {
    errors.password = 'Password must be at least 6 characters'
  }

  if (!form.confirmPassword) {
    errors.confirmPassword = 'Please confirm your password'
  } else if (form.password !== form.confirmPassword) {
    errors.confirmPassword = 'Passwords do not match'
  }

  if (!form.acceptTerms) {
    errors.acceptTerms = 'You must accept the terms and conditions'
  }

  return !Object.values(errors).some(error => error)
}

const handleSignUp = async () => {
  if (!validateForm()) return

  loading.value = true
  error.value = ''
  success.value = ''

  try {
    const { user, error: authError } = await authService.signUp({
      email: form.email,
      password: form.password,
      fullName: form.fullName
    })

    if (authError) {
      error.value = authError.message
    } else if (user) {
      success.value = 'Account created successfully! Please check your email to verify your account.'
      // Clear form
      Object.assign(form, {
        fullName: '',
        email: '',
        password: '',
        confirmPassword: '',
        acceptTerms: false
      })
    }
  } catch (err) {
    error.value = 'An unexpected error occurred. Please try again.'
    console.error('Sign up error:', err)
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.auth-container {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  padding: 20px;
}

.auth-card {
  background: white;
  border-radius: 12px;
  box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
  padding: 40px;
  width: 100%;
  max-width: 400px;
}

.auth-header {
  text-align: center;
  margin-bottom: 30px;
}

.auth-title {
  font-size: 28px;
  font-weight: 700;
  color: #2d3748;
  margin-bottom: 8px;
}

.auth-subtitle {
  color: #718096;
  font-size: 16px;
  margin: 0;
}

.auth-form {
  margin-bottom: 30px;
}

.form-group {
  margin-bottom: 20px;
}

.form-label {
  display: block;
  font-weight: 600;
  color: #2d3748;
  margin-bottom: 8px;
  font-size: 14px;
}

.form-control {
  width: 100%;
  padding: 12px 16px;
  border: 2px solid #e2e8f0;
  border-radius: 8px;
  font-size: 16px;
  transition: all 0.2s ease;
  background: #f8fafc;
}

.form-control:focus {
  outline: none;
  border-color: #667eea;
  background: white;
  box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
}

.form-control.is-invalid {
  border-color: #e53e3e;
  background: #fed7d7;
}

.password-input {
  position: relative;
}

.password-toggle {
  position: absolute;
  right: 12px;
  top: 50%;
  transform: translateY(-50%);
  background: none;
  border: none;
  color: #718096;
  cursor: pointer;
  padding: 4px;
  border-radius: 4px;
  transition: color 0.2s ease;
}

.password-toggle:hover {
  color: #2d3748;
}

.password-toggle:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.invalid-feedback {
  color: #e53e3e;
  font-size: 14px;
  margin-top: 4px;
}

.form-check {
  display: flex;
  align-items: flex-start;
}

.form-check-input {
  margin-right: 8px;
  margin-top: 2px;
}

.form-check-label {
  font-size: 14px;
  color: #4a5568;
  margin: 0;
  line-height: 1.4;
}

.terms-link {
  color: #667eea;
  text-decoration: underline;
}

.terms-link:hover {
  color: #5a67d8;
}

.alert {
  padding: 12px 16px;
  border-radius: 8px;
  margin-bottom: 20px;
  font-size: 14px;
  display: flex;
  align-items: center;
}

.alert-danger {
  background: #fed7d7;
  color: #c53030;
  border: 1px solid #feb2b2;
}

.alert-success {
  background: #c6f6d5;
  color: #2f855a;
  border: 1px solid #9ae6b4;
}

.auth-button {
  width: 100%;
  padding: 14px;
  font-size: 16px;
  font-weight: 600;
  border-radius: 8px;
  border: none;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  cursor: pointer;
  transition: all 0.2s ease;
  display: flex;
  align-items: center;
  justify-content: center;
}

.auth-button:hover:not(:disabled) {
  transform: translateY(-1px);
  box-shadow: 0 8px 20px rgba(102, 126, 234, 0.3);
}

.auth-button:disabled {
  opacity: 0.6;
  cursor: not-allowed;
  transform: none;
}

.auth-footer {
  text-align: center;
}

.auth-switch {
  color: #718096;
  font-size: 14px;
  margin: 0;
}

.auth-link {
  background: none;
  border: none;
  color: #667eea;
  font-weight: 600;
  cursor: pointer;
  text-decoration: underline;
  padding: 0;
}

.auth-link:hover:not(:disabled) {
  color: #5a67d8;
}

.auth-link:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.spinner-border-sm {
  width: 16px;
  height: 16px;
}
</style>
