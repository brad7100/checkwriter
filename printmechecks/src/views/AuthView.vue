<template>
  <div class="auth-view">
    <div class="login-container">
      <div class="login-card">
        <div class="login-header">
          <img src="/mycheckprinter.png" alt="My Check Printer" class="logo" />
          <h2>Sign In to CheckWriter</h2>
        </div>

        <form @submit.prevent="handleLogin" class="login-form">
          <div class="form-group">
            <label for="email">Email</label>
            <input
              id="email"
              v-model="email"
              type="email"
              class="form-control"
              placeholder="Enter your email"
              required
              :disabled="loading"
            />
          </div>

          <div class="form-group">
            <label for="password">Password</label>
            <input
              id="password"
              v-model="password"
              type="password"
              class="form-control"
              placeholder="Enter your password"
              required
              :disabled="loading"
            />
          </div>

          <div v-if="error" class="error-message">
            {{ error }}
          </div>

          <button
            type="submit"
            class="login-button"
            :disabled="loading || !email || !password"
          >
            <span v-if="loading" class="spinner"></span>
            {{ loading ? 'Signing In...' : 'Sign In' }}
          </button>
        </form>

        <div class="login-footer">
          <p>Don't have an account? <a href="#" @click="showSignup = true">Sign up</a></p>
        </div>
      </div>
    </div>

    <!-- Simple Signup Modal -->
    <div v-if="showSignup" class="modal-overlay" @click="showSignup = false">
      <div class="modal-content" @click.stop>
        <div class="modal-header">
          <h3>Create Account</h3>
          <button class="close-btn" @click="showSignup = false">&times;</button>
        </div>
        
        <form @submit.prevent="handleSignup" class="signup-form">
          <div class="form-group">
            <label for="signup-email">Email</label>
            <input
              id="signup-email"
              v-model="signupEmail"
              type="email"
              class="form-control"
              placeholder="Enter your email"
              required
              :disabled="loading"
            />
          </div>

          <div class="form-group">
            <label for="signup-password">Password</label>
            <input
              id="signup-password"
              v-model="signupPassword"
              type="password"
              class="form-control"
              placeholder="Create a password"
              required
              :disabled="loading"
            />
          </div>

          <div v-if="signupError" class="error-message">
            {{ signupError }}
          </div>

          <div v-if="signupSuccess" class="success-message">
            {{ signupSuccess }}
          </div>

          <button
            type="submit"
            class="signup-button"
            :disabled="loading || !signupEmail || !signupPassword"
          >
            <span v-if="loading" class="spinner"></span>
            {{ loading ? 'Creating Account...' : 'Create Account' }}
          </button>
        </form>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAppStore } from '@/stores/app'
import { authService } from '@/lib/auth'

const router = useRouter()
const store = useAppStore()

// Login form
const email = ref('')
const password = ref('')
const loading = ref(false)
const error = ref('')

// Signup form
const showSignup = ref(false)
const signupEmail = ref('')
const signupPassword = ref('')
const signupError = ref('')
const signupSuccess = ref('')

// Login handler
const handleLogin = async () => {
  loading.value = true
  error.value = ''

  try {
    const { user, error: authError } = await authService.signIn({
      email: email.value,
      password: password.value
    })

    if (authError) {
      error.value = authError.message
    } else if (user) {
      // Success - redirect to main app
      router.push('/')
    }
  } catch (err) {
    error.value = 'Login failed. Please try again.'
    console.error('Login error:', err)
  } finally {
    loading.value = false
  }
}

// Signup handler
const handleSignup = async () => {
  loading.value = true
  signupError.value = ''
  signupSuccess.value = ''

  try {
    const { user, error: authError } = await authService.signUp({
      email: signupEmail.value,
      password: signupPassword.value
    })

    if (authError) {
      signupError.value = authError.message
    } else if (user) {
      signupSuccess.value = 'Account created! Please check your email to verify your account.'
      // Clear form
      signupEmail.value = ''
      signupPassword.value = ''
      // Close modal after 3 seconds
      setTimeout(() => {
        showSignup.value = false
        signupSuccess.value = ''
      }, 3000)
    }
  } catch (err) {
    signupError.value = 'Signup failed. Please try again.'
    console.error('Signup error:', err)
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.auth-view {
  min-height: 100vh;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 20px;
}

.login-container {
  width: 100%;
  max-width: 400px;
}

.login-card {
  background: white;
  border-radius: 12px;
  box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
  padding: 40px;
}

.login-header {
  text-align: center;
  margin-bottom: 30px;
}

.logo {
  max-width: 150px;
  height: auto;
  margin-bottom: 20px;
}

.login-header h2 {
  color: #2d3748;
  margin: 0;
  font-size: 24px;
  font-weight: 600;
}

.login-form {
  margin-bottom: 20px;
}

.form-group {
  margin-bottom: 20px;
}

.form-group label {
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
  box-sizing: border-box;
}

.form-control:focus {
  outline: none;
  border-color: #667eea;
  box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
}

.form-control:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.error-message {
  background: #fed7d7;
  color: #c53030;
  padding: 12px 16px;
  border-radius: 8px;
  margin-bottom: 20px;
  font-size: 14px;
}

.success-message {
  background: #c6f6d5;
  color: #2f855a;
  padding: 12px 16px;
  border-radius: 8px;
  margin-bottom: 20px;
  font-size: 14px;
}

.login-button {
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
  gap: 8px;
}

.login-button:hover:not(:disabled) {
  transform: translateY(-1px);
  box-shadow: 0 8px 20px rgba(102, 126, 234, 0.3);
}

.login-button:disabled {
  opacity: 0.6;
  cursor: not-allowed;
  transform: none;
}

.login-footer {
  text-align: center;
}

.login-footer p {
  color: #718096;
  font-size: 14px;
  margin: 0;
}

.login-footer a {
  color: #667eea;
  text-decoration: none;
  font-weight: 600;
}

.login-footer a:hover {
  text-decoration: underline;
}

.spinner {
  width: 16px;
  height: 16px;
  border: 2px solid transparent;
  border-top: 2px solid currentColor;
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

/* Modal Styles */
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.modal-content {
  background: white;
  border-radius: 12px;
  box-shadow: 0 20px 40px rgba(0, 0, 0, 0.3);
  padding: 30px;
  width: 90%;
  max-width: 400px;
  max-height: 90vh;
  overflow-y: auto;
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
}

.modal-header h3 {
  color: #2d3748;
  margin: 0;
  font-size: 20px;
}

.close-btn {
  background: none;
  border: none;
  font-size: 24px;
  color: #718096;
  cursor: pointer;
  padding: 0;
  width: 30px;
  height: 30px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.close-btn:hover {
  color: #2d3748;
}

.signup-form {
  margin-bottom: 0;
}

.signup-button {
  width: 100%;
  padding: 14px;
  font-size: 16px;
  font-weight: 600;
  border-radius: 8px;
  border: none;
  background: linear-gradient(135deg, #48bb78 0%, #38a169 100%);
  color: white;
  cursor: pointer;
  transition: all 0.2s ease;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
}

.signup-button:hover:not(:disabled) {
  transform: translateY(-1px);
  box-shadow: 0 8px 20px rgba(72, 187, 120, 0.3);
}

.signup-button:disabled {
  opacity: 0.6;
  cursor: not-allowed;
  transform: none;
}
</style>
