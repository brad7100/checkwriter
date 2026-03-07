// Supabase Edge Function: invite-user
// Only admins can invite new users. Invited users receive an email to set their password.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Missing Authorization header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    // Verify caller is admin using their JWT
    // Get user id from JWT payload (works without getSession)
    const token = authHeader.replace('Bearer ', '')
    const parts = token.split('.')
    if (parts.length !== 3) {
      return new Response(
        JSON.stringify({ error: 'Invalid token' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    const payload = JSON.parse(
      new TextDecoder().decode(
        Uint8Array.from(atob(parts[1].replace(/-/g, '+').replace(/_/g, '/')), (c) => c.charCodeAt(0))
      )
    )
    const userId = payload.sub
    if (!userId) {
      return new Response(
        JSON.stringify({ error: 'Invalid token' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const adminClient = createClient(supabaseUrl, supabaseServiceKey)
    const { data: profile } = await adminClient
      .from('profiles')
      .select('role')
      .eq('id', userId)
      .single()

    if (profile?.role !== 'admin') {
      return new Response(
        JSON.stringify({ error: 'Only admins can invite users' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const body = await req.json()
    const email = typeof body?.email === 'string' ? body.email.trim() : ''
    const action = body?.action === 'reset' ? 'reset' : 'invite'
    if (!email) {
      return new Response(
        JSON.stringify({ error: 'Email is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const redirectTo = `${req.headers.get('origin') || supabaseUrl.replace('.supabase.co', '')}/`

    // Admin can send password reset to existing user (no password or forgot)
    if (action === 'reset') {
      const anonKey = Deno.env.get('SUPABASE_ANON_KEY')
      if (!anonKey) {
        return new Response(
          JSON.stringify({ error: 'Server config missing for password reset.' }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
      const anonClient = createClient(supabaseUrl, anonKey)
      const { error: resetError } = await anonClient.auth.resetPasswordForEmail(email, { redirectTo })
      if (resetError) {
        return new Response(
          JSON.stringify({ error: 'Could not send password reset: ' + resetError.message }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
      const { data: listData } = await adminClient.auth.admin.listUsers()
      const users = listData?.users ?? []
      const existing = users.find((u: { email?: string }) => u.email?.toLowerCase() === email.toLowerCase())
      if (existing?.id) {
        await adminClient.from('profiles').update({ must_set_password: true }).eq('id', existing.id)
      }
      return new Response(
        JSON.stringify({ message: 'Password reset email sent. They can set a password from the link.' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { data: inviteData, error: inviteError } = await adminClient.auth.admin.inviteUserByEmail(
      email,
      { redirectTo }
    )

    if (inviteError) {
      const msg = inviteError.message.toLowerCase()
      const isExistingUser =
        msg.includes('already') ||
        msg.includes('duplicate') ||
        msg.includes('already been registered') ||
        msg.includes('users_email_key')

      if (isExistingUser) {
        // User exists but may have no password — send password reset email
        const anonKey = Deno.env.get('SUPABASE_ANON_KEY')
        if (!anonKey) {
          return new Response(
            JSON.stringify({ error: 'That email is already registered. Server config missing for password reset.' }),
            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          )
        }
        const anonClient = createClient(supabaseUrl, anonKey)
        const { error: resetError } = await anonClient.auth.resetPasswordForEmail(email, {
          redirectTo,
        })
        if (resetError) {
          return new Response(
            JSON.stringify({
              error: 'That email is already registered. Could not send password reset: ' + resetError.message,
            }),
            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          )
        }
        // Force set-password flow when they land after clicking the reset link
        const { data: listData } = await adminClient.auth.admin.listUsers()
        const users = listData?.users ?? []
        const existing = users.find((u: { email?: string }) => u.email?.toLowerCase() === email.toLowerCase())
        if (existing?.id) {
          await adminClient.from('profiles').update({ must_set_password: true }).eq('id', existing.id)
        }
        return new Response(
          JSON.stringify({
            message:
              'That user already exists. A password reset email has been sent so they can set a password.',
          }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
      return new Response(
        JSON.stringify({ error: inviteError.message }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Require invited user to set a password on first login
    if (inviteData?.user?.id) {
      await adminClient
        .from('profiles')
        .update({ must_set_password: true })
        .eq('id', inviteData.user.id)
    }

    return new Response(
      JSON.stringify({
        message: 'Invitation sent. The user will receive an email to set their password.',
        user_id: inviteData?.user?.id,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (e) {
    return new Response(
      JSON.stringify({ error: e instanceof Error ? e.message : 'Invite failed' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
