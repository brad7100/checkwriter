import { supabase } from './supabase'
import type { User, Session, AuthError } from '@supabase/supabase-js'

export interface AuthUser {
  id: string
  email: string
  user_metadata: {
    full_name?: string
    avatar_url?: string
  }
}

export interface SignUpData {
  email: string
  password: string
  fullName?: string
}

export interface SignInData {
  email: string
  password: string
}

export interface AuthState {
  user: AuthUser | null
  session: Session | null
  loading: boolean
  error: string | null
}

class AuthService {
  private authState: AuthState = {
    user: null,
    session: null,
    loading: true,
    error: null
  }

  private listeners: ((state: AuthState) => void)[] = []

  constructor() {
    this.initializeAuth()
  }

  private async initializeAuth() {
    try {
      // Get initial session
      const { data: { session }, error } = await supabase.auth.getSession()
      
      if (error) {
        this.updateState({ error: error.message, loading: false })
        return
      }

      this.updateState({
        session,
        user: session?.user as AuthUser || null,
        loading: false
      })

      // Listen for auth changes
      supabase.auth.onAuthStateChange((event, session) => {
        this.updateState({
          session,
          user: session?.user as AuthUser || null,
          loading: false,
          error: null
        })
      })
    } catch (error) {
      this.updateState({ 
        error: error instanceof Error ? error.message : 'Authentication error',
        loading: false 
      })
    }
  }

  private updateState(updates: Partial<AuthState>) {
    this.authState = { ...this.authState, ...updates }
    this.listeners.forEach(listener => listener(this.authState))
  }

  // Subscribe to auth state changes
  subscribe(listener: (state: AuthState) => void) {
    this.listeners.push(listener)
    // Return current state immediately
    listener(this.authState)
    
    // Return unsubscribe function
    return () => {
      const index = this.listeners.indexOf(listener)
      if (index > -1) {
        this.listeners.splice(index, 1)
      }
    }
  }

  // Get current auth state
  getState(): AuthState {
    return { ...this.authState }
  }

  // Sign up with email and password
  async signUp({ email, password, fullName }: SignUpData): Promise<{ user: User | null; error: AuthError | null }> {
    try {
      this.updateState({ loading: true, error: null })
      
      const { data, error } = await supabase.auth.signUp({
        email,
        password,
        options: {
          data: {
            full_name: fullName
          }
        }
      })

      if (error) {
        this.updateState({ error: error.message, loading: false })
        return { user: null, error }
      }

      this.updateState({ loading: false })
      return { user: data.user, error: null }
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Sign up failed'
      this.updateState({ error: errorMessage, loading: false })
      return { user: null, error: { message: errorMessage } as AuthError }
    }
  }

  // Sign in with email and password
  async signIn({ email, password }: SignInData): Promise<{ user: User | null; error: AuthError | null }> {
    try {
      this.updateState({ loading: true, error: null })
      
      const { data, error } = await supabase.auth.signInWithPassword({
        email,
        password
      })

      if (error) {
        this.updateState({ error: error.message, loading: false })
        return { user: null, error }
      }

      this.updateState({ loading: false })
      return { user: data.user, error: null }
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Sign in failed'
      this.updateState({ error: errorMessage, loading: false })
      return { user: null, error: { message: errorMessage } as AuthError }
    }
  }

  // Sign out
  async signOut(): Promise<{ error: AuthError | null }> {
    try {
      this.updateState({ loading: true, error: null })
      
      const { error } = await supabase.auth.signOut()

      if (error) {
        this.updateState({ error: error.message, loading: false })
        return { error }
      }

      this.updateState({ 
        user: null, 
        session: null, 
        loading: false 
      })
      return { error: null }
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Sign out failed'
      this.updateState({ error: errorMessage, loading: false })
      return { error: { message: errorMessage } as AuthError }
    }
  }

  // Reset password
  async resetPassword(email: string): Promise<{ error: AuthError | null }> {
    try {
      this.updateState({ loading: true, error: null })
      
      const { error } = await supabase.auth.resetPasswordForEmail(email, {
        redirectTo: `${window.location.origin}/reset-password`
      })

      if (error) {
        this.updateState({ error: error.message, loading: false })
        return { error }
      }

      this.updateState({ loading: false })
      return { error: null }
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Password reset failed'
      this.updateState({ error: errorMessage, loading: false })
      return { error: { message: errorMessage } as AuthError }
    }
  }

  // Update user profile
  async updateProfile(updates: { full_name?: string; avatar_url?: string }): Promise<{ error: AuthError | null }> {
    try {
      this.updateState({ loading: true, error: null })
      
      const { error } = await supabase.auth.updateUser({
        data: updates
      })

      if (error) {
        this.updateState({ error: error.message, loading: false })
        return { error }
      }

      this.updateState({ loading: false })
      return { error: null }
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Profile update failed'
      this.updateState({ error: errorMessage, loading: false })
      return { error: { message: errorMessage } as AuthError }
    }
  }
}

// Create singleton instance
export const authService = new AuthService()
