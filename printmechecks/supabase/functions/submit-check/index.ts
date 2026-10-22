// Supabase Edge Function: submit-check
// Allows automated bots to submit checks for approval without exposing the service role key
// Authentication: Requires a scoped API key stored in Supabase secrets table

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-submitter-key',
}

interface CheckSubmission {
  account_id: string
  pay_to: string
  amount: string
  date: string
  memo?: string
  check_number?: string
  expense_category?: string
  business_unit?: string
}

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Get the submitter API key from custom header
    const submitterKey = req.headers.get('X-Submitter-Key')
    if (!submitterKey) {
      return new Response(
        JSON.stringify({ error: 'Missing X-Submitter-Key header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    const adminClient = createClient(supabaseUrl, supabaseServiceKey)

    // Verify the submitter key against stored keys in the database
    const { data: keyData, error: keyError } = await adminClient
      .from('submitter_api_keys')
      .select('id, user_id, name, is_active, last_used_at')
      .eq('key_hash', submitterKey)
      .eq('is_active', true)
      .single()

    if (keyError || !keyData) {
      return new Response(
        JSON.stringify({ error: 'Invalid or inactive API key' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Update last used timestamp
    await adminClient
      .from('submitter_api_keys')
      .update({ last_used_at: new Date().toISOString() })
      .eq('id', keyData.id)

    // Parse the check submission
    const body = await req.json()
    const check: CheckSubmission = {
      account_id: body.account_id,
      pay_to: body.pay_to,
      amount: body.amount,
      date: body.date,
      memo: body.memo,
      check_number: body.check_number,
      expense_category: body.expense_category,
      business_unit: body.business_unit,
    }

    // Validate required fields
    if (!check.account_id || !check.pay_to || !check.amount || !check.date) {
      return new Response(
        JSON.stringify({ 
          error: 'Missing required fields: account_id, pay_to, amount, and date are required' 
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Get bank account details to populate check fields
    const { data: accountData, error: accountError } = await adminClient
      .from('bank_accounts')
      .select(`
        id,
        name,
        bank_name,
        bank_city,
        routing_number,
        account_number,
        signature,
        company_id,
        companies!inner(
          name,
          address,
          city,
          state,
          zip
        )
      `)
      .eq('id', check.account_id)
      .single()

    if (accountError || !accountData) {
      return new Response(
        JSON.stringify({ error: 'Bank account not found or access denied' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Verify the API key's user has access to this account
    const { data: accessData } = await adminClient
      .from('account_users')
      .select('id')
      .eq('user_id', keyData.user_id)
      .eq('bank_account_id', check.account_id)
      .single()

    if (!accessData) {
      return new Response(
        JSON.stringify({ error: 'API key does not have access to this bank account' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Check for duplicates
    const { data: duplicates } = await adminClient.rpc('check_for_duplicates', {
      p_account_id: check.account_id,
      p_payee: check.pay_to,
      p_amount: check.amount,
    })

    const hasDuplicates = duplicates && duplicates.length > 0

    // Generate check number if not provided
    let checkNumber = check.check_number
    if (!checkNumber) {
      // Get the highest check number for this account
      const { data: lastCheck } = await adminClient
        .from('checks')
        .select('check_number')
        .eq('account_id', check.account_id)
        .order('check_number', { ascending: false })
        .limit(1)
        .single()

      const lastNum = lastCheck?.check_number ? parseInt(lastCheck.check_number) : 1000
      checkNumber = (lastNum + 1).toString()
    }

    // Build the full check object
    const company = accountData.companies
    const fullCheck = {
      company_id: accountData.company_id,
      account_id: check.account_id,
      account_holder_name: company.name,
      account_holder_address: company.address,
      account_holder_city: company.city,
      account_holder_state: company.state,
      account_holder_zip: company.zip,
      check_number: checkNumber,
      date: check.date,
      bank_name: accountData.bank_name,
      amount: check.amount,
      pay_to: check.pay_to,
      memo: check.memo || '',
      signature: accountData.signature,
      routing_number: accountData.routing_number,
      bank_account_number: accountData.account_number,
      expense_category: check.expense_category,
      business_unit: check.business_unit,
      status: 'pending',
      created_by: keyData.user_id,
      is_printed: false,
    }

    // Insert the check
    const { data: insertedCheck, error: insertError } = await adminClient
      .from('checks')
      .insert(fullCheck)
      .select()
      .single()

    if (insertError) {
      return new Response(
        JSON.stringify({ error: 'Failed to create check: ' + insertError.message }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Return success with duplicate warning if applicable
    return new Response(
      JSON.stringify({
        success: true,
        check_id: insertedCheck.id,
        check_number: insertedCheck.check_number,
        status: 'pending',
        duplicate_warning: hasDuplicates,
        duplicates: hasDuplicates ? duplicates : undefined,
        message: hasDuplicates 
          ? 'Check submitted successfully but similar checks were found in the last 7 days'
          : 'Check submitted successfully and is pending approval',
      }),
      { status: 201, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (e) {
    return new Response(
      JSON.stringify({ error: e instanceof Error ? e.message : 'Check submission failed' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
