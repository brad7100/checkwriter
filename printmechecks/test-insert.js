import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://cffhvhgvaidwofyceoju.supabase.co'
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNmZmh2aGd2YWlkd29meWNlb2p1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk2ODUwOTMsImV4cCI6MjA3NTI2MTA5M30.AXL9vIG4i_SlNPFq-211HoR_PubKg1TtCHo4kWR6kPU'

const supabase = createClient(supabaseUrl, supabaseAnonKey)

async function testInsert() {
  console.log('🧪 Testing simple company insert...\n')
  
  try {
    // Just insert the minimal required fields, let Supabase generate the ID
    const { data, error } = await supabase
      .from('companies')
      .insert([
        {
          name: 'Test Company',
          address: '123 Main St',
          city: 'Anytown',
          state: 'CA',
          zip: '12345'
        }
      ])
      .select()
    
    if (error) {
      console.error('❌ ERROR:', error.message)
      console.error('Details:', error)
      return
    }
    
    console.log('✅ SUCCESS! Company inserted:')
    console.log(JSON.stringify(data, null, 2))
    
    // Now try with a crypto.randomUUID()
    console.log('\n🧪 Testing with crypto.randomUUID()...\n')
    
    const uuid = crypto.randomUUID()
    console.log('Generated UUID:', uuid)
    
    const { data: data2, error: error2 } = await supabase
      .from('companies')
      .insert([
        {
          id: uuid,
          name: 'Test Company 2',
          address: '456 Oak Ave',
          city: 'Somewhere',
          state: 'NY',
          zip: '67890'
        }
      ])
      .select()
    
    if (error2) {
      console.error('❌ ERROR:', error2.message)
      console.error('Details:', error2)
      return
    }
    
    console.log('✅ SUCCESS! Company inserted with UUID:')
    console.log(JSON.stringify(data2, null, 2))
    
  } catch (err) {
    console.error('❌ EXCEPTION:', err.message)
    console.error(err)
  }
}

testInsert()

