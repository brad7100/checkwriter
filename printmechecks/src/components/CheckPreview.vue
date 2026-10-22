<template>
  <div class="check-preview">
    <div class="check-box" :style="checkBoxStyle">
      <div class="check-content">
        <!-- Account Holder Info -->
        <div class="account-holder-name" style="position: absolute; top: 40px; left: 60px">
          {{ check.company_name }}
        </div>
        <div class="account-holder-address" style="position: absolute; top: 70px; left: 60px">
          <!-- Address would come from check data -->
          {{ check.account_holder_address || '' }}<br v-if="check.account_holder_address">
          {{ check.account_holder_city }}, {{ check.account_holder_state }} {{ check.account_holder_zip }}
        </div>
        
        <!-- Check Number -->
        <div class="check-number-human" style="position: absolute; top: 40px; left: 1060px">
          {{ check.check_number }}
        </div>
        
        <!-- Date -->
        <div class="date-data" style="position: absolute; top: 80px; left: 850px">
          {{ check.date }}
        </div>
        <div class="date" style="position: absolute; top: 90px; left: 760px">
          Date: _____________________
        </div>
        
        <!-- Amount Box -->
        <div class="amount-box" style="position: absolute; top: 175px; left: 950px"></div>
        <div class="amount-data" style="position: absolute; top: 182px; left: 970px">
          $ {{ formatMoney(check.amount) }}
        </div>
        
        <!-- Pay To -->
        <div class="pay-to-data" style="position: absolute; top: 180px; left: 180px">
          {{ check.pay_to }}
        </div>
        <div class="pay-to" style="position: absolute; top: 170px; left: 60px">
          Pay to the <br>Order of <span class="payto-line"></span>
        </div>
        
        <!-- Amount in Words -->
        <div class="amount-line-data" style="position: absolute; top: 240px; left: 100px">
          *** {{ toWords(check.amount) }} ***
        </div>
        <div class="amount-line" style="position: absolute; top: 250px; left: 60px">
          <span class="dollar-line"></span>
        </div>
        
        <!-- Bank Name -->
        <div class="bank-name" style="position: absolute; top: 300px; left: 60px">
          {{ check.bank_name }}
        </div>
        
        <!-- Memo -->
        <div class="memo-data" style="position: absolute; top: 367px; left: 120px">
          {{ check.memo }}
        </div>
        <div class="memo" style="position: absolute; top: 390px; left: 60px">
          Memo: ____________________________________
        </div>
        
        <!-- Signature (shown as placeholder for preview) -->
        <div class="signature-data" style="position: absolute; top: 366px; left: 770px">
          [Signature]
        </div>
        <div class="signature" style="position: absolute; top: 390px; left: 750px">
          _________________________________________________
        </div>
        
        <!-- MICR Line (masked for preview) -->
        <div class="banking" style="position: absolute; top: 420px; left: 147px">
          <div class="routing" style="display: inline;">
            a****{{ maskNumber(check.routing_number || '', 4) }}a
          </div>
          <div class="bank-account" style="display: inline;">
            ****{{ maskNumber(check.bank_account_number || '', 4) }}c
          </div>
          <div class="check-number" style="display: inline; margin-left:20px">
            {{ check.check_number }}
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'

interface Check {
  id?: string
  check_number: string
  date: string
  pay_to: string
  amount: string
  memo?: string
  bank_name: string
  company_name: string
  account_holder_address?: string
  account_holder_city?: string
  account_holder_state?: string
  account_holder_zip?: string
  routing_number?: string
  bank_account_number?: string
  [key: string]: any
}

const props = defineProps<{
  check: Check
}>()

const checkBoxStyle = computed(() => ({
  width: '1200px',
  height: '500px',
  border: '1px solid #ccc',
  position: 'relative',
  background: 'white',
  fontFamily: 'Arial, sans-serif',
  margin: '0 auto',
}))

function formatMoney(amount: string | number): string {
  if (!amount) return '0.00'
  const cleaned = amount.toString().replace(/[$,]/g, '')
  const num = parseFloat(cleaned)
  return num.toFixed(2).replace(/\B(?=(\d{3})+(?!\d))/g, ',')
}

function toWords(amount: string | number): string {
  if (!amount) return 'Zero'
  
  const cleaned = amount.toString().replace(/[$,]/g, '')
  const num = parseFloat(cleaned)
  
  const ones = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine']
  const tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety']
  const teens = ['Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen']
  
  function convertLessThanThousand(n: number): string {
    if (n === 0) return ''
    
    if (n < 10) return ones[n]
    if (n < 20) return teens[n - 10]
    if (n < 100) {
      const ten = Math.floor(n / 10)
      const one = n % 10
      return tens[ten] + (one > 0 ? ' ' + ones[one] : '')
    }
    
    const hundred = Math.floor(n / 100)
    const remainder = n % 100
    return ones[hundred] + ' Hundred' + (remainder > 0 ? ' ' + convertLessThanThousand(remainder) : '')
  }
  
  const dollars = Math.floor(num)
  const cents = Math.round((num - dollars) * 100)
  
  if (dollars === 0) {
    return cents > 0 ? `Zero Dollars and ${cents}/100` : 'Zero Dollars'
  }
  
  let result = ''
  
  if (dollars >= 1000000) {
    const millions = Math.floor(dollars / 1000000)
    result += convertLessThanThousand(millions) + ' Million '
    const remainder = dollars % 1000000
    if (remainder > 0) result += convertLessThanThousand(remainder)
  } else if (dollars >= 1000) {
    const thousands = Math.floor(dollars / 1000)
    result += convertLessThanThousand(thousands) + ' Thousand '
    const remainder = dollars % 1000
    if (remainder > 0) result += convertLessThanThousand(remainder)
  } else {
    result = convertLessThanThousand(dollars)
  }
  
  result = result.trim() + ' Dollars'
  
  if (cents > 0) {
    result += ` and ${cents}/100`
  }
  
  return result
}

function maskNumber(num: string, lastDigits: number): string {
  if (!num || num.length <= lastDigits) return num
  return num.slice(-lastDigits)
}
</script>

<style scoped>
.check-preview {
  width: 100%;
  overflow-x: auto;
  padding: 20px 0;
}

.check-box {
  transform: scale(0.8);
  transform-origin: top center;
}

.check-content {
  position: relative;
  width: 100%;
  height: 100%;
}

.account-holder-name {
  font-size: 16px;
  font-weight: bold;
}

.account-holder-address {
  font-size: 12px;
  color: #333;
}

.check-number-human {
  font-size: 20px;
  font-weight: bold;
  color: #333;
}

.date-data {
  font-size: 14px;
  font-weight: 500;
}

.date {
  font-size: 12px;
  color: #666;
}

.amount-box {
  width: 150px;
  height: 35px;
  border: 2px solid #333;
}

.amount-data {
  font-size: 18px;
  font-weight: bold;
  color: #000;
}

.pay-to-data {
  font-size: 16px;
  font-weight: 500;
}

.pay-to {
  font-size: 11px;
  color: #666;
}

.payto-line {
  display: inline-block;
  width: 600px;
  border-bottom: 1px solid #333;
}

.amount-line-data {
  font-size: 12px;
  font-weight: 500;
}

.dollar-line {
  display: inline-block;
  width: 1050px;
  border-bottom: 1px solid #333;
}

.bank-name {
  font-size: 14px;
  font-weight: bold;
}

.memo-data {
  font-size: 12px;
}

.memo {
  font-size: 11px;
  color: #666;
}

.signature-data {
  font-size: 24px;
  font-family: 'Brush Script MT', cursive;
  font-style: italic;
  color: #666;
}

.signature {
  font-size: 11px;
  color: #666;
}

.banking {
  font-family: 'MICR', monospace;
  font-size: 37px;
  color: #000;
  letter-spacing: 2px;
}

.routing,
.bank-account,
.check-number {
  display: inline-block;
  margin-right: 15px;
}
</style>
