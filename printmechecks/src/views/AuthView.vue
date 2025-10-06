<template>
  <div class="simple-login">
    <div class="login-box">
      <h1>CheckWriter Login</h1>
      
      <form @submit.prevent="login">
        <input 
          v-model="email" 
          type="email" 
          placeholder="Email" 
          required 
        />
        <input 
          v-model="password" 
          type="password" 
          placeholder="Password" 
          required 
        />
        
        <div v-if="error" class="error">{{ error }}</div>
        
        <button type="submit" :disabled="loading">
          {{ loading ? 'Logging in...' : 'Login' }}
        </button>
      </form>
      
      <p class="signup-link">
        Need an account? <a href="#" @click="showSignup = true">Sign up</a>
      </p>
    </div>

    <!-- Simple Signup -->
    <div v-if="showSignup" class="signup-overlay" @click="showSignup = false">
      <div class="signup-box" @click.stop>
        <h2>Create Account</h2>
        <form @submit.prevent="signup">
          <input 
            v-model="signupEmail" 
            type="email" 
            placeholder="Email" 
            required 
          />
          <input 
            v-model="signupPassword" 
            type="password" 
            placeholder="Password" 
            required 
          />
          
          <div v-if="signupError" class="error">{{ signupError }}</div>
          <div v-if="signupSuccess" class="success">{{ signupSuccess }}</div>
          
          <button type="submit" :disabled="loading">
            {{ loading ? 'Creating...' : 'Create Account' }}
          </button>
        </form>
        <button class="close" @click="showSignup = false">×</button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/lib/supabase'

const router = useRouter()

// Login
const email = ref('')
const password = ref('')
const loading = ref(false)
const error = ref('')

// Signup
const showSignup = ref(false)
const signupEmail = ref('')
const signupPassword = ref('')
const signupError = ref('')
const signupSuccess = ref('')

// Simple login function
const login = async () => {
  loading.value = true
  error.value = ''
  
  try {
    const { data, error: authError } = await supabase.auth.signInWithPassword({
      email: email.value,
      password: password.value
    })
    
    if (authError) {
      error.value = authError.message
    } else {
      // Success - go to main app
      router.push('/')
    }
  } catch (err) {
    error.value = 'Login failed'
  } finally {
    loading.value = false
  }
}

// Simple signup function
const signup = async () => {
  loading.value = true
  signupError.value = ''
  signupSuccess.value = ''
  
  try {
    const { data, error: authError } = await supabase.auth.signUp({
      email: signupEmail.value,
      password: signupPassword.value
    })
    
    if (authError) {
      signupError.value = authError.message
    } else {
      signupSuccess.value = 'Account created! Check your email.'
      signupEmail.value = ''
      signupPassword.value = ''
      setTimeout(() => {
        showSignup.value = false
        signupSuccess.value = ''
      }, 2000)
    }
  } catch (err) {
    signupError.value = 'Signup failed'
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.simple-login {
  min-height: 100vh;
  background: #f5f5f5;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 20px;
}

.login-box {
  background: white;
  padding: 40px;
  border-radius: 8px;
  box-shadow: 0 2px 10px rgba(0,0,0,0.1);
  width: 100%;
  max-width: 400px;
}

.login-box h1 {
  text-align: center;
  margin-bottom: 30px;
  color: #333;
  font-size: 24px;
}

.login-box form {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.login-box input {
  padding: 12px;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-size: 16px;
}

.login-box input:focus {
  outline: none;
  border-color: #007bff;
}

.login-box button {
  padding: 12px;
  background: #007bff;
  color: white;
  border: none;
  border-radius: 4px;
  font-size: 16px;
  cursor: pointer;
}

.login-box button:hover:not(:disabled) {
  background: #0056b3;
}

.login-box button:disabled {
  background: #ccc;
  cursor: not-allowed;
}

.error {
  color: #dc3545;
  text-align: center;
  padding: 10px;
  background: #f8d7da;
  border-radius: 4px;
}

.success {
  color: #155724;
  text-align: center;
  padding: 10px;
  background: #d4edda;
  border-radius: 4px;
}

.signup-link {
  text-align: center;
  margin-top: 20px;
}

.signup-link a {
  color: #007bff;
  text-decoration: none;
}

.signup-link a:hover {
  text-decoration: underline;
}

/* Signup Modal */
.signup-overlay {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: rgba(0,0,0,0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.signup-box {
  background: white;
  padding: 30px;
  border-radius: 8px;
  box-shadow: 0 4px 20px rgba(0,0,0,0.3);
  width: 90%;
  max-width: 400px;
  position: relative;
}

.signup-box h2 {
  margin-bottom: 20px;
  color: #333;
  text-align: center;
}

.signup-box form {
  display: flex;
  flex-direction: column;
  gap: 15px;
}

.signup-box input {
  padding: 10px;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-size: 16px;
}

.signup-box input:focus {
  outline: none;
  border-color: #007bff;
}

.signup-box button {
  padding: 10px;
  background: #28a745;
  color: white;
  border: none;
  border-radius: 4px;
  font-size: 16px;
  cursor: pointer;
}

.signup-box button:hover:not(:disabled) {
  background: #218838;
}

.signup-box button:disabled {
  background: #ccc;
  cursor: not-allowed;
}

.close {
  position: absolute;
  top: 10px;
  right: 15px;
  background: none;
  border: none;
  font-size: 24px;
  cursor: pointer;
  color: #999;
}

.close:hover {
  color: #333;
}
</style>
