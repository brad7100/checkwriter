<template>
  <div class="login-page">
    <h1>Login</h1>
    
    <form @submit.prevent="handleLogin">
      <div>
        <input 
          v-model="username" 
          type="text" 
          placeholder="Username/Email" 
          required 
        />
      </div>
      
      <div>
        <input 
          v-model="password" 
          type="password" 
          placeholder="Password" 
          required 
        />
      </div>
      
      <div v-if="error" class="error">{{ error }}</div>
      
      <button type="submit">Login</button>
    </form>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/lib/supabase'

const router = useRouter()

const username = ref('')
const password = ref('')
const error = ref('')

const handleLogin = async () => {
  error.value = ''
  
  try {
    const { data, error: authError } = await supabase.auth.signInWithPassword({
      email: username.value,
      password: password.value
    })
    
    if (authError) {
      error.value = authError.message
    } else {
      router.push('/')
    }
  } catch (err) {
    error.value = 'Login failed'
  }
}
</script>

<style scoped>
.login-page {
  max-width: 400px;
  margin: 100px auto;
  padding: 20px;
}

.login-page h1 {
  text-align: center;
  margin-bottom: 30px;
}

.login-page form div {
  margin-bottom: 15px;
}

.login-page input {
  width: 100%;
  padding: 10px;
  border: 1px solid #ccc;
  border-radius: 4px;
  font-size: 16px;
  box-sizing: border-box;
}

.login-page button {
  width: 100%;
  padding: 12px;
  background: #007bff;
  color: white;
  border: none;
  border-radius: 4px;
  font-size: 16px;
  cursor: pointer;
}

.login-page button:hover {
  background: #0056b3;
}

.error {
  color: red;
  text-align: center;
  margin-top: 10px;
}
</style>
