<template>
    <div class="wrapper" id="wrapper" style="position: relative;">
        <div class="check-box" id="check-box" :style="checkBoxStyle">
            
            
            <div style="position: relative;" id="check-box-print">
                <!-- No Account Selected Overlay: show when no account or account not assigned to user -->
                <div v-if="!hasValidSelectedAccount" class="no-account-overlay">
                    <div class="no-account-message">
                        <i class="bi bi-exclamation-triangle-fill"></i>
                        <h3>No Account Selected</h3>
                        <p>Please select a company and bank account to create a check</p>
                    </div>
                </div>

                <!-- Original Layout: only show account data when user has a valid selected account -->
                <template v-if="!currentTemplate">
                <div class="account-holder-name" style="position: absolute; top: 40px; left: 60px">{{hasValidSelectedAccount ? check.accountHolderName : ''}}</div>
                <div class="account-holder-address" style="position: absolute; top: 70px; left: 60px">
                    <template v-if="hasValidSelectedAccount">{{check.accountHolderAddress}}<br>
                    {{check.accountHolderCity}}, {{check.accountHolderState}} {{check.accountHolderZip}}</template>
                </div>
                <div class="check-number-human" style="position: absolute; top: 40px; left: 1060px">{{hasValidSelectedAccount ? check.checkNumber : ''}}</div>
                <div class="date-data" style="position: absolute; top: 80px; left: 850px">{{hasValidSelectedAccount ? check.date : ''}}</div>
                <div class="date" style="position: absolute; top: 90px; left: 760px">Date: _____________________ </div>
                <div class="amount-box" style="position: absolute; top: 175px; left: 950px">

                </div>
                    <div class="amount-data" style="position: absolute; top: 182px; left: 970px">{{hasValidSelectedAccount ? '$ ' + formatMoney(check.amount) : ''}}</div>
                <div class="pay-to-data" style="position: absolute; top: 180px; left: 180px">{{hasValidSelectedAccount ? check.payTo : ''}}</div>
                <div class="pay-to" style="position: absolute; top: 170px; left: 60px">
                    Pay to the <br>Order of <span class="payto-line"></span>
                </div>
                <div class="amount-line-data" ref="line" style="position: absolute; top: 240px; left: 100px">
                    <template v-if="hasValidSelectedAccount">***
                    {{toWords(check.amount)}} 
                    ***</template>
                </div>
                <div class="amount-line" style="position: absolute; top: 250px; left: 60px">
                    <span class="dollar-line"></span>
                </div>
                <div class="bank-name" style="position: absolute; top: 300px; left: 60px">{{hasValidSelectedAccount ? check.bankName : ''}}</div>
                <div class="memo-data" style="position: absolute; top: 367px; left: 120px">{{hasValidSelectedAccount ? check.memo : ''}}</div>
                <div class="memo" style="position: absolute; top: 390px; left: 60px">
                    Memo: ____________________________________
                </div>
                <div class="signature-data" style="position: absolute; top: 366px; left: 770px">{{hasValidSelectedAccount ? check.signature : ''}}</div>
                <div class="signature" style="position: absolute; top: 390px; left: 750px">
                    _________________________________________________
                </div>
                </template>

                <!-- Custom Layout -->
                <template v-else>
                    <!-- Custom Fields (excluding MICR, routing number, and check number for preprinted) -->
                    <div 
                        v-for="field in currentTemplate.fields.filter(f => {
                            if (isPreprinted.value) {
                                return f.id !== 'micr-line' && f.id !== 'routingNumber' && f.id !== 'checkNumber'
                            }
                            return f.id !== 'micr-line'
                        })" 
                        :key="field.id"
                        :style="getFieldStyle(field)"
                    >
                        {{ getFieldContent(field) }}
                    </div>
                    
                    <!-- Custom Drawing Elements -->
                    <div 
                        v-for="element in currentTemplate.drawingElements" 
                        :key="element.id"
                        class="drawing-element"
                        :style="getElementStyle(element)"
                    >
                    </div>
                </template>
                
                
                
                <!-- Fixed MICR Line (only show if user has valid account selected and not preprinted) -->
                <div v-if="hasValidSelectedAccount && !isPreprinted" class="banking" style="position: absolute; top: 420px; left: 147px">
                    <div class="routing" style="display: inline;">
                        a{{check.routingNumber}}a
                    </div>
                    <div class="bank-account" style="display: inline;">{{check.bankAccountNumber}}c</div>
                    <div class="check-number" style="display: inline; margin-left:20px">{{check.checkNumber}}</div>
                </div>
            </div>
        </div>
        <div class="check-data" style="position: absolute; top: 450px">
            <!-- Ready to Print Queue: FIRST THING - shows unprinted checks created by automation -->
            <div v-if="hasValidSelectedAccount" 
                 class="ready-to-print-queue" 
                 style="margin-bottom: 20px; border: 2px solid #0d6efd; border-radius: 8px; padding: 16px; background-color: #e7f3ff;">
                <h5 style="margin-bottom: 16px; color: #0d6efd;">
                    <i class="bi bi-printer-fill"></i> Ready to Print 
                    <span v-if="unprintedChecks.length > 0" class="badge bg-primary">{{ unprintedChecks.length }}</span>
                </h5>
                
                <!-- Empty state -->
                <div v-if="unprintedChecks.length === 0" style="color: #6c757d; font-size: 14px; font-style: italic;">
                    <i class="bi bi-check-circle"></i> No checks waiting to print
                </div>
                
                <!-- Queue content -->
                <div v-else>
                    <p style="margin-bottom: 12px; font-size: 14px; color: #495057;">
                        Checks created by automation (Terry / Send to Controller) awaiting review and printing.
                    </p>
                    <div class="table-responsive">
                        <table class="table table-sm table-hover bg-white">
                            <thead>
                                <tr>
                                    <th style="width: 30px;">
                                        <input type="checkbox" 
                                               v-model="selectAllChecks" 
                                               @change="toggleSelectAll"
                                               title="Select all">
                                    </th>
                                    <th>Date</th>
                                    <th>Check #</th>
                                    <th>Payee</th>
                                    <th>Amount</th>
                                    <th>Memo</th>
                                    <th>Actions</th>
                                </tr>
                            </thead>
                            <tbody>
                                <tr v-for="unpCheck in unprintedChecks" :key="unpCheck.id">
                                    <td>
                                        <input type="checkbox" 
                                               v-model="selectedCheckIds" 
                                               :value="unpCheck.id">
                                    </td>
                                    <td>{{ unpCheck.date }}</td>
                                    <td>{{ unpCheck.checkNumber }}</td>
                                    <td>{{ unpCheck.payTo }}</td>
                                    <td>${{ formatMoney(unpCheck.amount) }}</td>
                                    <td>{{ unpCheck.memo || '-' }}</td>
                                    <td>
                                        <button class="btn btn-sm btn-primary me-1" 
                                                @click="loadCheckForEditing(unpCheck)"
                                                title="Edit and print">
                                            <i class="bi bi-pencil"></i> Edit
                                        </button>
                                        <button class="btn btn-sm btn-success me-1" 
                                                @click="printCheckDirectly(unpCheck)"
                                                title="Print as-is">
                                            <i class="bi bi-printer"></i> Print
                                        </button>
                                        <button class="btn btn-sm btn-outline-secondary" 
                                                @click="markAsPrinted(unpCheck)"
                                                title="Mark as printed without printing">
                                            <i class="bi bi-check-circle"></i> Mark Printed
                                        </button>
                                    </td>
                                </tr>
                            </tbody>
                        </table>
                    </div>
                    <div style="margin-top: 12px;">
                        <button class="btn btn-success me-2" @click="batchPrintUnprinted" :disabled="unprintedChecks.length === 0">
                            <i class="bi bi-printer-fill"></i> Batch Print All ({{ unprintedChecks.length }})
                        </button>
                        <button class="btn btn-outline-secondary" 
                                @click="markSelectedAsPrinted" 
                                :disabled="selectedCheckIds.length === 0"
                                title="Mark selected checks as printed without printing">
                            <i class="bi bi-check-circle-fill"></i> Mark Selected as Printed ({{ selectedCheckIds.length }})
                        </button>
                    </div>
                </div>
            </div>

            <button type="button" style="float: right;" class="btn btn-primary" @click="printCheck">Print (Ctrl + P)</button>
            
            <!-- Check Options -->
            <div style="margin-bottom: 20px; padding: 15px; background-color: #f8f9fa; border-radius: 8px;">
                <!-- Preprinted Check Toggle -->
                <div class="row" v-if="state.selectedAccountId">
                    <div class="col-12">
                        <div class="form-check">
                            <input class="form-check-input" type="checkbox" v-model="isPreprinted" id="preprintedToggle">
                            <label class="form-check-label" for="preprintedToggle">
                                <strong>Preprinted Check</strong> - Hide MICR line, routing number, and check number
                            </label>
                        </div>
                        <div v-if="isPreprinted && !state.customLayouts.find(l => l.name === 'preprinted')" class="alert alert-warning mt-2" style="font-size: 12px;">
                            <i class="bi bi-exclamation-triangle"></i> 
                            <strong>No "preprinted" template found!</strong> 
                            Go to Layout Editor and create a template named "preprinted" to customize your preprinted check layout.
                            <br>
                            <button class="btn btn-sm btn-outline-primary mt-1" @click="createPreprintedTemplate">
                                <i class="bi bi-plus-circle"></i> Create Preprinted Template
                            </button>
                        </div>
                    </div>
                </div>

                <!-- Stub Template Selection -->
                <div class="row mt-3" v-if="state.selectedAccountId">
                    <div class="col-12">
                        <label class="form-label"><strong>Stub Template</strong></label>
                        <select class="form-select" v-model="selectedStubTemplateId">
                            <option value="default">Default Stub</option>
                            <option v-for="template in stubTemplates" :key="template.id" :value="template.id">
                                {{ template.name }}
                            </option>
                        </select>
                        <small class="form-text text-muted">Choose a template for the check stubs (record-keeping sections)</small>
                </div>
                </div>
                </div>

            <!-- Check basics: number, date, expense category -->
            <form class="row g-3" style="margin-top: 20px; border-top: 1px solid #e7e7e7; padding-top: 12px;">
                <div class="col-md-2">
                    <label class="form-label">Check Number</label>
                    <input type="text" class="form-control" v-model="check.checkNumber">
                </div>
                <div class="col-md-2">
                    <label class="form-label">Date</label>
                    <input type="text" class="form-control" v-model="check.date">
                </div>
                <div class="col-md-4">
                    <label class="form-label">Expense Category</label>
                    <select class="form-select" v-model="expenseCategory">
                        <option v-for="c in expenseCategories" :key="c" :value="c">{{ c }}</option>
                    </select>
                </div>
                <div class="col-md-4">
                    <label class="form-label">Memo</label>
                    <input type="text" class="form-control" v-model="check.memo">
                </div>
            </form>

            <!-- Payee and amount -->
            <form class="row g-3" style="margin-top: 20px; border-top: 1px solid #e7e7e7; padding-top: 12px;">
                <div class="col-md-6">
                    <label class="form-label">Payee</label>
                    <input type="text" class="form-control" v-model="check.payTo">
                </div>
                <div class="col-md-2">
                    <label class="form-label">Amount</label>
                    <input type="text" class="form-control" v-model="check.amount">
                </div>
            </form>

            <!-- Payee address (linked to Mail To fields) -->
            <form class="row g-3" style="margin-top: 20px; border-top: 1px solid #e7e7e7; padding-top: 12px;">
                <div class="col-md-6">
                    <label class="form-label">Payee Address</label>
                    <input type="text" class="form-control" v-model="check.mailToAddress">
                </div>
                <div class="col-md-2">
                    <label class="form-label">City</label>
                    <input type="text" class="form-control" v-model="check.mailToCity">
                </div>
                <div class="col-md-2">
                    <label class="form-label">State</label>
                    <input type="text" class="form-control" v-model="check.mailToState">
                </div>
                <div class="col-md-2">
                    <label class="form-label">ZIP</label>
                    <input type="text" class="form-control" v-model="check.mailToZip">
                </div>
            </form>
            <div class="col-12" style="margin-top: 30px;">
                <button type="button" class="btn btn-primary me-2" @click="saveToHistory">Save Check</button>
                <button type="button" class="btn btn-outline-secondary" @click="printCheck">Print Check</button>
            </div>
        </div>
    </div>
</template>

<script setup lang="ts">
import print from 'print-js';
import { ToWords } from 'to-words';
import { ref, reactive, computed, nextTick, watch, onMounted, onUnmounted } from 'vue'
import { formatMoney } from '../utilities.ts'
import { useAppStore } from '../stores/app.ts'
import { useRouter } from 'vue-router'

const state = useAppStore()
const router = useRouter()
const isPreprinted = ref(false)

// Only treat as "account selected" when it's one the user is allowed to see (avoids showing another account in background)
const hasValidSelectedAccount = computed(() =>
  !!state.selectedAccountId && state.visibleBankAccounts.some((a) => a.id === state.selectedAccountId)
)

// Ready to Print queue: unprinted checks created by automation
const unprintedChecks = ref([])
const selectedCheckIds = ref([])
const selectAllChecks = ref(false)

const loadUnprintedChecks = async () => {
  if (state.selectedAccountId) {
    unprintedChecks.value = await state.getUnprintedChecks(state.selectedAccountId)
  } else {
    unprintedChecks.value = []
  }
  // Clear selections when reloading
  selectedCheckIds.value = []
  selectAllChecks.value = false
}

const toggleSelectAll = () => {
  if (selectAllChecks.value) {
    selectedCheckIds.value = unprintedChecks.value.map(c => c.id)
  } else {
    selectedCheckIds.value = []
  }
}

// Template switching
const selectedTemplateId = ref('original')
const selectedStubTemplateId = ref('default')

// Stub templates (templates with names containing "stub")
const stubTemplates = computed(() => {
  return state.customLayouts.filter(layout => 
    layout.name.toLowerCase().includes('stub')
  )
})
const currentTemplate = computed(() => {
  // If preprinted toggle is on, use the "preprinted" template
  if (isPreprinted.value) {
    console.log('🔍 Preprinted toggle ON - Looking for preprinted template...')
    console.log('All customLayouts from store:', state.customLayouts)
    console.log('Available templates:', state.customLayouts.map(l => ({ id: l.id, name: l.name })))
    
    const preprintedTemplate = state.customLayouts.find(layout => layout.name === 'preprinted')
    console.log('Found preprinted template:', preprintedTemplate)
    
    if (preprintedTemplate) {
      console.log('✅ Using preprinted template')
      return preprintedTemplate
    } else {
      console.log('❌ Preprinted template not found')
      return null // This will show the original template
    }
  }
  
  console.log('🔍 Preprinted toggle OFF - Using normal template:', selectedTemplateId.value)
  if (selectedTemplateId.value === 'original') {
    return null
  }
  return state.customLayouts.find(layout => layout.id === selectedTemplateId.value)
})

// Current stub template
const currentStubTemplate = computed(() => {
  if (selectedStubTemplateId.value === 'default') {
    return null // Use default stub
  }
  return state.customLayouts.find(layout => layout.id === selectedStubTemplateId.value)
})

// (No fixed check number overlay; add as a field in layout editor)

// Check box style with color filter as background gradient (only when user has valid selected account)
const checkBoxStyle = computed(() => {
  if (!hasValidSelectedAccount.value) return {}
  if (state.selectedAccount?.backgroundColor) {
    // Convert hex to rgba with 20% opacity for overlay
    const hex = state.selectedAccount.backgroundColor
    const r = parseInt(hex.slice(1, 3), 16)
    const g = parseInt(hex.slice(3, 5), 16)
    const b = parseInt(hex.slice(5, 7), 16)
    
    // Layer color gradient on top of the existing background image from CSS
    // Import the image path dynamically
    const bgImageUrl = new URL('../assets/checkbg.png', import.meta.url).href
    return {
      backgroundImage: `linear-gradient(to bottom, rgba(${r}, ${g}, ${b}, 0.2) 0%, rgba(${r}, ${g}, ${b}, 0.2) 410px, transparent 410px), url(${bgImageUrl})`
    }
  }
  return {}
})

const switchTemplate = () => {
  // Template switching is handled by the computed property
  console.log('Switched to template:', selectedTemplateId.value)
}

// Expense categories (simple example list) and selected category
const expenseCategories = [
  'Rent',
  'Utilities',
  'Supplies',
  'Payroll',
  'Travel',
  'Meals & Entertainment',
  'Professional Services',
  'Other'
]
const expenseCategory = ref(expenseCategories[0])

const getFieldStyle = (field: any) => {
  return {
    position: 'absolute',
    left: `${field.x}px`,
    top: `${field.y}px`,
    width: `${field.width}px`,
    height: `${field.height}px`,
    fontFamily: field.fontFamily,
    fontSize: `${field.fontSize}px`,
    fontWeight: field.fontWeight ? 'bold' : 'normal',
    fontStyle: field.fontStyle ? 'italic' : 'normal',
    color: field.color,
    textAlign: field.textAlign || 'left',
    cursor: 'default',
    userSelect: 'none',
    whiteSpace: 'pre-line'
  }
}

const getFieldContent = (field: any) => {
  if (field.dataBinding) {
    return getDataValue(field.dataBinding)
  }
  return field.text
}

const getElementStyle = (element: any) => {
  const baseStyle = {
    position: 'absolute',
    left: `${element.x}px`,
    top: `${element.y}px`,
    width: `${element.width}px`,
    height: `${element.height}px`,
    border: `${element.strokeWidth}px solid ${element.strokeColor}`,
    backgroundColor: element.fillColor || 'transparent',
    transform: element.rotation ? `rotate(${element.rotation}deg)` : 'none',
    transformOrigin: 'center',
    zIndex: 5
  }

  if (element.type === 'line') {
    return {
      ...baseStyle,
      border: 'none',
      height: `${element.strokeWidth || 2}px`,
      backgroundColor: 'transparent',
      borderTop: `${element.strokeWidth || 2}px solid ${element.strokeColor || '#000'}`
    }
  }

  return baseStyle
}


const getDataValue = (dataBinding: string) => {
  if (!hasValidSelectedAccount.value) return ''
  switch (dataBinding) {
    case 'accountHolderName':
      return state.selectedCompany?.name || 'Company Name'
    case 'accountHolderAddress':
      return state.selectedCompany?.address || 'Address'
    case 'accountHolderCity':
      return state.selectedCompany?.city || 'City'
    case 'accountHolderState':
      return state.selectedCompany?.state || 'State'
    case 'accountHolderZip':
      return state.selectedCompany?.zip || 'ZIP'
    case 'accountHolderCityStateZip':
    case 'accountHolderCityState':
      return `${state.selectedCompany?.city || 'City'}, ${state.selectedCompany?.state || 'ST'} ${state.selectedCompany?.zip || '00000'}`
    case 'payerName':
      return state.selectedCompany?.name || 'Payer Company Name'
    case 'payerAddress':
      return state.selectedCompany?.address || 'Payer Address'
    case 'payerCityState':
      return `${state.selectedCompany?.city || 'City'}, ${state.selectedCompany?.state || 'ST'} ${state.selectedCompany?.zip || '00000'}`
    case 'mailToName':
      return check.mailToName || ''
    case 'mailToAddress':
    case 'payeeAddress':
      return check.mailToAddress || ''
    case 'mailToCity':
      return check.mailToCity || ''
    case 'mailToState':
      return check.mailToState || ''
    case 'mailToZip':
      return check.mailToZip || ''
    case 'mailToCityStateZip':
    case 'payeeCityStateZip':
      return `${check.mailToCity || ''}, ${check.mailToState || ''} ${check.mailToZip || ''}`.trim()
    case 'checkNumber':
      return check.checkNumber
    case 'date':
      return check.date
    case 'amount':
      return '$ ' + formatMoney(check.amount)
    case 'amountWords': {
      const amount = Number(check.amount || 0)
      const dollars = Math.floor(amount)
      const cents = Math.round((amount - dollars) * 100)
      const dollarsWords = dollars === 0 ? 'Zero' : toWordsTool.convert(dollars)
      const centsStr = cents.toString().padStart(2, '0')
      return `*** ${dollarsWords} and ${centsStr}/100 Dollars ***`
    }
    case 'payTo':
      return check.payTo
    case 'bankName':
      return state.selectedAccount?.bankName || 'Bank Name'
    case 'bankCity':
      return state.selectedAccount?.bankCity || 'Bank City'
    case 'accountName':
      return state.selectedAccount?.name || 'Account Name'
    case 'memo':
      return check.memo
    case 'signature':
      return check.signature
    case 'routingNumber':
      return check.routingNumber
    default:
      return ''
  }
}

// Create stub content using template or default
const createStubContent = (stubType: 'payee' | 'bank') => {
  if (currentStubTemplate.value) {
    // Use custom stub template
    const template = currentStubTemplate.value
    let content = ''
    
    if (template.fields) {
      template.fields.forEach(field => {
        const fieldContent = getFieldContent(field)
        const styleObj = getFieldStyle(field)
        
        // Convert style object to CSS string
        const styleString = Object.entries(styleObj)
          .map(([key, value]) => `${key.replace(/([A-Z])/g, '-$1').toLowerCase()}: ${value}`)
          .join('; ')
        
        content += `<div style="position: absolute; ${styleString}">${fieldContent}</div>`
      })
    }
    
    if (template.drawingElements) {
      template.drawingElements.forEach(element => {
        const elementStyleObj = getElementStyle(element)
        const styleString = Object.entries(elementStyleObj)
          .map(([key, value]) => `${key.replace(/([A-Z])/g, '-$1').toLowerCase()}: ${value}`)
          .join('; ')
        
        content += `<div style="position: absolute; ${styleString}"></div>`
      })
    }
    
    return content
  } else {
    // Use default stub content
    const stubData = {
      payee: {
        title: 'Check Stub - Payee Copy',
        fields: [
          { label: 'Company:', value: state.selectedCompany?.name || 'N/A' },
          { label: 'Account:', value: state.selectedAccount?.name || 'N/A' },
          { label: 'Check #:', value: check.checkNumber },
          { label: 'Date:', value: check.date },
          { label: 'Pay to:', value: check.payTo },
          { label: 'Amount:', value: '$' + formatMoney(check.amount) },
          { label: 'Memo:', value: check.memo }
        ]
      },
      bank: {
        title: 'Check Stub - Bank Copy',
        fields: [
          { label: 'Company:', value: state.selectedCompany?.name || 'N/A' },
          { label: 'Account:', value: state.selectedAccount?.name || 'N/A' },
          { label: 'Check #:', value: check.checkNumber },
          { label: 'Date:', value: check.date },
          { label: 'Pay to:', value: check.payTo },
          { label: 'Amount:', value: '$' + formatMoney(check.amount) },
          { label: 'Memo:', value: check.memo },
          { label: 'Routing:', value: check.routingNumber },
          { label: 'Account #:', value: check.bankAccountNumber }
        ]
      }
    }
    
    const data = stubData[stubType]
    let content = `
      <div class="stub-content">
        <div class="stub-header">${data.title}</div>
    `
    
    data.fields.forEach(field => {
      content += `<div><strong>${field.label}</strong> ${field.value}</div>`
    })
    
    content += '</div>'
    return content
  }
}

const toWordsTool = new ToWords({
  localeCode: 'en-US',
  converterOptions: {
    currency: true,
    ignoreDecimal: false,
    ignoreZeroCurrency: false,
    doNotAddOnly: true,
  },
});

const toWords: (denom: number | string) => string = (denom) => {
    try {
        return toWordsTool.convert(Number(denom), );
    } catch (e) {
        return `${e}`;
    }
}

async function printCheck () {
    // Always save the check first (create or update)
    if (check.id) {
        // Update existing check and mark as printed
        check.isPrinted = true
        check.printedDate = new Date().toISOString()
        
        await state.updateCheck(check.id, {
            ...check,
            isPrinted: true,
            printedDate: check.printedDate
        })
    } else {
        // Create new check and mark as printed
        check.isPrinted = true
        check.printedDate = new Date().toISOString()
        
        const savedCheck = await state.saveCheck({...check})
        check.id = savedCheck.id
    }
    
    // Clear draft after successful print
    if (state.selectedAccountId) {
        state.clearDraftCheck(state.selectedAccountId)
    }
    
    if (isPreprinted.value) {
        // Use preprinted template for printing with native print dialog
        const preprintedTemplate = state.customLayouts.find(layout => layout.name === 'preprinted')
        if (!preprintedTemplate) {
            alert('Preprinted template not found. Please create a "preprinted" template in the Layout Editor.')
            return
        }
        
        // Create a temporary div with the preprinted check content
        const tempDiv = document.createElement('div')
        tempDiv.style.position = 'absolute'
        tempDiv.style.left = '-9999px'
        tempDiv.style.top = '-9999px'
        tempDiv.style.width = '612px'
        tempDiv.style.height = '792px'
        tempDiv.style.border = '1px solid #e6e6e6'
        tempDiv.style.backgroundColor = 'white'
        tempDiv.style.margin = '0 auto'
        tempDiv.style.position = 'relative'
        
        // Add fields from preprinted template
        if (preprintedTemplate.fields) {
            preprintedTemplate.fields.forEach(field => {
                const content = getFieldContent(field)
                const styleObj = getFieldStyle(field)
                const fieldDiv = document.createElement('div')
                fieldDiv.textContent = content
                
                // Apply styles
                Object.entries(styleObj).forEach(([key, value]) => {
                    fieldDiv.style[key] = value
                })
                
                tempDiv.appendChild(fieldDiv)
            })
        }
        
        // Add drawing elements
        if (preprintedTemplate.drawingElements) {
            preprintedTemplate.drawingElements.forEach(element => {
                const elementStyleObj = getElementStyle(element)
                const elementDiv = document.createElement('div')
                
                // Apply styles
                Object.entries(elementStyleObj).forEach(([key, value]) => {
                    elementDiv.style[key] = value
                })
                
                tempDiv.appendChild(elementDiv)
            })
        }
        
        // Add stub sections - properly positioned for QuickBooks check paper
        const stub1Div = document.createElement('div')
        stub1Div.style.position = 'absolute'
        stub1Div.style.top = '525px'
        stub1Div.style.left = '150px'
        stub1Div.style.transform = 'scale(1.5)'
        stub1Div.style.transformOrigin = 'top left'
        stub1Div.style.width = '612px'
        stub1Div.style.height = '300px'
        stub1Div.style.border = '1px solid #ccc'
        stub1Div.style.backgroundColor = 'white'
        stub1Div.style.padding = '20px'
        stub1Div.style.boxSizing = 'border-box'
        stub1Div.innerHTML = createStubContent('payee')
        
        const stub2Div = document.createElement('div')
        stub2Div.style.position = 'absolute'
        stub2Div.style.top = '1000px'
        stub2Div.style.left = '150px'
        stub2Div.style.transform = 'scale(1.5)'
        stub2Div.style.transformOrigin = 'top left'
        stub2Div.style.width = '612px'
        stub2Div.style.height = '300px'
        stub2Div.style.border = '1px solid #ccc'
        stub2Div.style.backgroundColor = 'white'
        stub2Div.style.padding = '20px'
        stub2Div.style.boxSizing = 'border-box'
        stub2Div.innerHTML = createStubContent('bank')
        
        // Add to document temporarily
        document.body.appendChild(tempDiv)
        document.body.appendChild(stub1Div)
        document.body.appendChild(stub2Div)
        
        // Create print styles
        const style = document.createElement('style')
        style.textContent = `
          @media print {
            @page {
              margin: 0;
            }
            body {
              transform: scale(1);
              transform-origin: top center;
              width: 145%;
              margin: 0;
              padding: 0;
            }
            .wrapper > *:not(.check-box) {
              display: none !important;
            }
            .check-data {
                display: none;
            }
            .check-box {
              position: fixed;
              top: 0;
              left: 0;
              width: 100%;
              height: 100%;
              margin: 0;
              padding: 0px;
              background-color: white;
              background: white !important;
              border: none !important;
              box-shadow: none !important;
            }
            .banking {
              font-family: 'banking' !important;
              font-size: 37px !important;
            }
            .check-box-print {
              position: relative;
            }
          }
        `
        document.head.appendChild(style)
        
        // Print
        window.print()
        
        // Clean up
        document.body.removeChild(tempDiv)
        document.body.removeChild(stub1Div)
        document.body.removeChild(stub2Div)
        document.head.removeChild(style)
    } else {
        // Regular print with MICR line - add stub sections
        const stub1Div = document.createElement('div')
        stub1Div.style.position = 'absolute'
        stub1Div.style.top = '525px'
        stub1Div.style.left = '150px'
        stub1Div.style.transform = 'scale(1.5)'
        stub1Div.style.transformOrigin = 'top left'
        stub1Div.style.width = '612px'
        stub1Div.style.height = '300px'
        stub1Div.style.border = '1px solid #ccc'
        stub1Div.style.backgroundColor = 'white'
        stub1Div.style.padding = '20px'
        stub1Div.style.boxSizing = 'border-box'
        stub1Div.innerHTML = createStubContent('payee')
        
        const stub2Div = document.createElement('div')
        stub2Div.style.position = 'absolute'
        stub2Div.style.top = '1000px'
        stub2Div.style.left = '150px'
        stub2Div.style.transform = 'scale(1.5)'
        stub2Div.style.transformOrigin = 'top left'
        stub2Div.style.width = '612px'
        stub2Div.style.height = '300px'
        stub2Div.style.border = '1px solid #ccc'
        stub2Div.style.backgroundColor = 'white'
        stub2Div.style.padding = '20px'
        stub2Div.style.boxSizing = 'border-box'
        stub2Div.innerHTML = createStubContent('bank')
        
        document.body.appendChild(stub1Div)
        document.body.appendChild(stub2Div)
        
    const style = document.createElement('style');
    style.textContent = `
      @media print {
        @page {
          margin: 0;
        }
        body {
          transform: scale(1);
          transform-origin: top center;
          width: 145%;
          margin: 0;
          padding: 0;
        }
        .wrapper > *:not(.check-box) {
          display: none !important;
        }
        .check-data {
            display: none;
        }
        .check-box {
          position: fixed;
          top: 0;
          left: 0;
          width: 100%;
          height: 100%;
          margin: 0;
          padding: 0px;
          background-color: white;
          background: white !important;
          border: none !important;
          box-shadow: none !important;
        }
            .banking {
              font-family: 'banking' !important;
              font-size: 37px !important;
        }
        .check-box-print {
          position: relative;
        }
      }
    `;
    document.head.appendChild(style);
        window.print(); // Opens native print preview dialog
    style.remove();
    document.body.removeChild(stub1Div);
    document.body.removeChild(stub2Div);
}
}

async function saveToHistory () {
    // Mark as unprinted (only when saving without printing)
    check.isPrinted = false
    check.printedDate = null
    
    // Save to Supabase
    const savedCheck = await state.saveCheck({...check}) // Clone to avoid reference issues
    
    // Update the local check with the saved ID
    if (!check.id) {
        check.id = savedCheck.id
    }
    
    // Clear draft after successful save
    if (state.selectedAccountId) {
        state.clearDraftCheck(state.selectedAccountId)
    }
    
    alert('Check saved successfully!')
}

// Ready-to-Print queue functions
async function loadCheckForEditing(unprintedCheck) {
    // Load the unprinted check into the editor
    Object.assign(check, unprintedCheck)
    
    // Scroll to the form
    await nextTick(() => {
        const formElement = document.querySelector('form')
        if (formElement) {
            formElement.scrollIntoView({ behavior: 'smooth' })
        }
    })
}

async function printCheckDirectly(unprintedCheck) {
    // Print the check as-is without loading into editor
    const checkToUse = { ...unprintedCheck }
    
    // Mark as printed
    checkToUse.isPrinted = true
    checkToUse.printedDate = new Date().toISOString()
    
    await state.updateCheck(checkToUse.id, checkToUse)
    
    // Print logic (simplified version of printCheck)
    if (isPreprinted.value) {
        const preprintedTemplate = state.customLayouts.find(layout => layout.name === 'preprinted')
        if (!preprintedTemplate) {
            alert('Preprinted template not found.')
            return
        }
        const printWindow = window.open('', '_blank')
        const checkHtml = await generateCheckHtml(checkToUse, preprintedTemplate)
        printWindow.document.write(checkHtml)
        printWindow.document.close()
        printWindow.onload = () => {
            printWindow.print()
            printWindow.close()
        }
    } else {
        const printWindow = window.open('', '_blank')
        const checkHtml = await generateCheckHtml(checkToUse, currentTemplate.value)
        printWindow.document.write(checkHtml)
        printWindow.document.close()
        printWindow.onload = () => {
            printWindow.print()
            printWindow.close()
        }
    }
    
    // Reload the unprinted queue
    await loadUnprintedChecks()
    alert('Check printed successfully!')
}

async function batchPrintUnprinted() {
    if (unprintedChecks.value.length === 0) return
    
    if (!confirm(`Print ${unprintedChecks.value.length} checks?`)) return
    
    // Mark all as printed
    const updates = unprintedChecks.value.map(check => ({
        ...check,
        isPrinted: true,
        printedDate: new Date().toISOString()
    }))
    
    // Update all in database
    for (const checkToUpdate of updates) {
        await state.updateCheck(checkToUpdate.id, checkToUpdate)
    }
    
    // Generate combined HTML for all checks
    const printWindow = window.open('', '_blank')
    let combinedHtml = '<html><head><style>@page { size: letter; margin: 0; } @media print { .page-break { page-break-after: always; } }</style></head><body>'
    
    for (let i = 0; i < updates.length; i++) {
        const checkData = updates[i]
        const checkHtml = await generateCheckHtml(checkData, currentTemplate.value)
        combinedHtml += checkHtml
        if (i < updates.length - 1) {
            combinedHtml += '<div class="page-break"></div>'
        }
    }
    
    combinedHtml += '</body></html>'
    
    printWindow.document.write(combinedHtml)
    printWindow.document.close()
    printWindow.onload = () => {
        printWindow.print()
        printWindow.close()
    }
    
    // Reload the unprinted queue
    await loadUnprintedChecks()
    alert(`Batch printed ${updates.length} checks successfully!`)
}

async function markAsPrinted(unprintedCheck) {
    // Confirm before marking
    const confirmMsg = `Mark check #${unprintedCheck.checkNumber} to ${unprintedCheck.payTo} as printed?\n\nThis will NOT print the check, only mark it as printed in the system.`
    if (!confirm(confirmMsg)) return
    
    try {
        // Update check with printed status (same format as normal print)
        await state.updateCheck(unprintedCheck.id, {
            ...unprintedCheck,
            isPrinted: true,
            printedDate: new Date().toISOString()
        })
        
        // Reload the unprinted queue
        await loadUnprintedChecks()
        
        // Success message
        alert(`Check #${unprintedCheck.checkNumber} marked as printed.`)
    } catch (error) {
        console.error('Error marking check as printed:', error)
        alert(`Failed to mark check as printed: ${error.message}`)
    }
}

async function markSelectedAsPrinted() {
    if (selectedCheckIds.value.length === 0) return
    
    const confirmMsg = `Mark ${selectedCheckIds.value.length} selected check(s) as printed?\n\nThis will NOT print the checks, only mark them as printed in the system.`
    if (!confirm(confirmMsg)) return
    
    try {
        // Get the checks to update
        const checksToMark = unprintedChecks.value.filter(c => selectedCheckIds.value.includes(c.id))
        
        // Update all selected checks
        for (const checkToMark of checksToMark) {
            await state.updateCheck(checkToMark.id, {
                ...checkToMark,
                isPrinted: true,
                printedDate: new Date().toISOString()
            })
        }
        
        // Reload the unprinted queue
        await loadUnprintedChecks()
        
        // Success message
        alert(`${checksToMark.length} check(s) marked as printed.`)
    } catch (error) {
        console.error('Error marking checks as printed:', error)
        alert(`Failed to mark checks as printed: ${error.message}`)
    }
}

// Helper to generate check HTML for printing
async function generateCheckHtml(checkData, template) {
    // Simplified HTML generation - you may need to adjust based on your template rendering
    const toWords = new ToWords({
        localeCode: 'en-US',
        converterOptions: { currency: true }
    })
    const amountWords = toWords.convert(parseFloat(checkData.amount) || 0)
    
    return `
        <div style="width: 850px; height: 350px; position: relative; border: 1px solid #ccc; margin: 20px; padding: 20px;">
            <div style="position: absolute; top: 40px; left: 60px; font-weight: bold;">${checkData.accountHolderName}</div>
            <div style="position: absolute; top: 70px; left: 60px;">
                ${checkData.accountHolderAddress}<br>
                ${checkData.accountHolderCity}, ${checkData.accountHolderState} ${checkData.accountHolderZip}
            </div>
            <div style="position: absolute; top: 40px; right: 60px; font-weight: bold;">Check #${checkData.checkNumber}</div>
            <div style="position: absolute; top: 80px; right: 100px;">Date: ${checkData.date}</div>
            <div style="position: absolute; top: 130px; left: 100px; font-size: 18px;">Pay to the order of: <strong>${checkData.payTo}</strong></div>
            <div style="position: absolute; top: 130px; right: 60px; border: 2px solid #000; padding: 5px;">$${formatMoney(checkData.amount)}</div>
            <div style="position: absolute; top: 170px; left: 100px; font-style: italic;">${amountWords}</div>
            <div style="position: absolute; top: 210px; left: 100px;">Memo: ${checkData.memo}</div>
            <div style="position: absolute; bottom: 40px; right: 100px; font-family: cursive;">${checkData.signature}</div>
            <div style="position: absolute; bottom: 20px; left: 60px; font-size: 10px;">
                ⑆${checkData.routingNumber}⑆ ${checkData.bankAccountNumber} ${checkData.checkNumber}
            </div>
        </div>
    `
}


async function getNextCheckNumber(accountId) {
    if (!accountId) return '1000'
    
    // Get all checks for this specific account
    const checkList = await state.getChecks()
    let accountChecks = checkList.filter(c => c.accountId === accountId)
    
    if (accountChecks.length === 0) {
        return '1000' // Start at 1000 for new accounts
    }
    
    // Find the highest check number for this account
    let maxCheckNumber = Math.max(...accountChecks.map(c => parseInt(c.checkNumber) || 0))
    return String(maxCheckNumber + 1)
}

async function genNewCheck () {
    const checkList = await state.getChecks()
    let recentCheck = checkList[checkList.length - 1]
    let check = {}
    
    // Use selected company and account data if available
    if (state.selectedCompany && state.selectedAccount) {
        check.companyId = state.selectedCompanyId
        check.accountId = state.selectedAccountId
        check.accountHolderName = state.selectedCompany.name
        check.accountHolderAddress = state.selectedCompany.address
        check.accountHolderCity = state.selectedCompany.city
        check.accountHolderState = state.selectedCompany.state
        check.accountHolderZip = state.selectedCompany.zip
        check.bankName = state.selectedAccount.bankName
        check.routingNumber = state.selectedAccount.routingNumber
        check.bankAccountNumber = state.selectedAccount.accountNumber
        check.signature = state.selectedAccount.signature
        
        // Get next check number for this specific account
        check.checkNumber = await getNextCheckNumber(state.selectedAccountId)
    } else {
        // Fallback to recent check or defaults
        check.companyId = recentCheck?.companyId || ''
        check.accountId = recentCheck?.accountId || ''
        check.accountHolderName = recentCheck?.accountHolderName || ''
        check.accountHolderAddress = recentCheck?.accountHolderAddress || ''
        check.accountHolderCity = recentCheck?.accountHolderCity || ''
        check.accountHolderState = recentCheck?.accountHolderState || ''
        check.accountHolderZip = recentCheck?.accountHolderZip || ''
        check.bankName = recentCheck?.bankName || ''
        check.routingNumber = recentCheck?.routingNumber || ''
        check.bankAccountNumber = recentCheck?.bankAccountNumber || ''
        check.signature = recentCheck?.signature || ''
        
        // Get next check number for the account if available
        check.checkNumber = check.accountId ? await getNextCheckNumber(check.accountId) : '1000'
    }
    
    check.date = new Date().toLocaleDateString()
    check.amount = '0.00'
    check.payTo = ''
    check.memo = ''
    
    // Mailing address fields
    check.mailToName = recentCheck?.mailToName || ''
    check.mailToAddress = recentCheck?.mailToAddress || ''
    check.mailToSuite = recentCheck?.mailToSuite || ''
    check.mailToCity = recentCheck?.mailToCity || ''
    check.mailToState = recentCheck?.mailToState || ''
    check.mailToZip = recentCheck?.mailToZip || ''
    
    return check
}

const check = reactive({
    id: '',
    companyId: '',
    accountId: '',
    accountHolderName: '',
    accountHolderAddress: '',
    accountHolderCity: '',
    accountHolderState: '',
    accountHolderZip: '',
    checkNumber: '100',
    date: new Date().toLocaleDateString(),
    bankName: '',
    amount: '0.00',
    payTo: '',
    memo: '',
    signature: '',
    routingNumber: '',
    bankAccountNumber: '',
    mailToName: '',
    mailToAddress: '',
    mailToSuite: '',
    mailToCity: '',
    mailToState: '',
    mailToZip: '',
    isPrinted: false,
    printedDate: null
})

// Helper function to scroll to top robustly
const scrollToTop = () => {
    // Scroll window
    window.scrollTo(0, 0)
    
    // Also scroll the main element if it exists and is scrollable
    const mainElement = document.querySelector('main')
    if (mainElement) {
        mainElement.scrollTop = 0
    }
    
    // Scroll any wrapper containers
    const wrapperElement = document.getElementById('wrapper')
    if (wrapperElement) {
        wrapperElement.scrollTop = 0
    }
}

// Initialize check data asynchronously
onMounted(async () => {
    // Load unprinted checks queue
    await loadUnprintedChecks()
    
    // Priority 1: Load existing check being edited (from History or reprint)
    if (state.check) {
        check.id = state.check.id
        check.accountHolderName = state.check.accountHolderName
        check.accountHolderAddress = state.check.accountHolderAddress
        check.accountHolderCity = state.check.accountHolderCity
        check.accountHolderState = state.check.accountHolderState
        check.accountHolderZip = state.check.accountHolderZip
        check.checkNumber = state.check.checkNumber
        check.date = state.check.date
        check.bankName = state.check.bankName
        check.amount = state.check.amount
        check.payTo = state.check.payTo
        check.memo = state.check.memo
        check.signature = state.check.signature
        check.routingNumber = state.check.routingNumber
        check.bankAccountNumber = state.check.bankAccountNumber
        check.companyId = state.check.companyId
        check.accountId = state.check.accountId
        check.isPrinted = state.check.isPrinted
        check.printedDate = state.check.printedDate
        state.check = null
    } 
    // Priority 2: Load draft check for this account (if returning to tab)
    else if (state.selectedAccountId) {
        const draft = state.getDraftCheck(state.selectedAccountId)
        if (draft && Object.keys(draft).length > 0) {
            Object.assign(check, draft)
        } else {
            // Priority 3: Generate a new check
            const newCheck = await genNewCheck()
            Object.assign(check, newCheck)
        }
    } else {
        // Fallback: Generate a new check
        const newCheck = await genNewCheck()
        Object.assign(check, newCheck)
    }
    
    // Scroll to top after nextTick (after initial render)
    await nextTick()
    scrollToTop()
    
    // Scroll again after a short delay to handle async content
    setTimeout(scrollToTop, 100)
})

const line = ref(null)

watch(check, async () => {
    await nextTick(() => {
        let computedLine = line?.value?.clientWidth
        check.lineLength = computedLine
    })
    
    // Save draft whenever check changes (debounced by reactivity)
    if (state.selectedAccountId && !check.id) {
        // Only save drafts for unsaved checks
        state.saveDraftCheck(state.selectedAccountId, { ...check })
    }
}, { immediate: true, deep: true })

// Watch for changes in selected company or account
watch([() => state.selectedCompanyId, () => state.selectedAccountId], async () => {
    // Reload unprinted checks when account changes
    await loadUnprintedChecks()
    
    if (state.selectedCompany && state.selectedAccount) {
        check.companyId = state.selectedCompanyId
        check.accountId = state.selectedAccountId
        check.accountHolderName = state.selectedCompany.name
        check.accountHolderAddress = state.selectedCompany.address
        check.accountHolderCity = state.selectedCompany.city
        check.accountHolderState = state.selectedCompany.state
        check.accountHolderZip = state.selectedCompany.zip
        check.bankName = state.selectedAccount.bankName
        check.routingNumber = state.selectedAccount.routingNumber
        check.bankAccountNumber = state.selectedAccount.accountNumber
        check.signature = state.selectedAccount.signature
        
        // Update check number for the newly selected account (await async call)
        check.checkNumber = await getNextCheckNumber(state.selectedAccountId)
        
        // Load account's default template
        console.log('Selected Account:', state.selectedAccount)
        console.log('Default Layout ID:', state.selectedAccount.defaultLayoutId)
        console.log('Available Layouts:', state.customLayouts.map(l => ({ id: l.id, name: l.name })))
        
        if (state.selectedAccount.defaultLayoutId) {
            selectedTemplateId.value = state.selectedAccount.defaultLayoutId
            console.log('Loading custom layout:', selectedTemplateId.value)
        } else {
            selectedTemplateId.value = 'original'
            console.log('No default layout set, using original')
        }
        
        // Scroll to top after account selection and data loads
        await nextTick()
        scrollToTop()
        
        // Scroll again after async content settles
        setTimeout(scrollToTop, 100)
    } else {
        selectedTemplateId.value = 'original'
    }
})

// Also watch for changes to the account's defaultLayoutId directly
watch(() => state.selectedAccount?.defaultLayoutId, (newLayoutId) => {
    console.log('Account defaultLayoutId changed to:', newLayoutId)
    if (newLayoutId) {
        selectedTemplateId.value = newLayoutId
    } else {
        selectedTemplateId.value = 'original'
    }
}, { immediate: true })

// Watch for when custom layouts are loaded
watch(() => state.customLayouts, (newLayouts) => {
    console.log('Custom layouts updated:', newLayouts.map(l => ({ id: l.id, name: l.name })))
}, { deep: true })

// Watch for when visibleBankAccounts loads (in case it's empty at mount)
watch(() => state.visibleBankAccounts, async (newAccounts) => {
    // If we have a selected account and accounts just loaded, reload the unprinted queue
    if (state.selectedAccountId && newAccounts && newAccounts.length > 0) {
        await loadUnprintedChecks()
    }
}, { deep: true })

function handlePrintShortcut(event: KeyboardEvent) {
    if (event.ctrlKey && event.key === 'p') {
        event.preventDefault();
        printCheck();
    }
}

function createPreprintedTemplate() {
    // Navigate to the layout editor to create a new preprinted template
    router.push('/layout-editor')
}

onMounted(() => {
    window.addEventListener('keydown', handlePrintShortcut);
});

onUnmounted(() => {
    window.removeEventListener('keydown', handlePrintShortcut);
});

</script>

<style>
.drawing-element {
  z-index: 5;
}

.no-account-overlay {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 410px;
  background-color: rgba(255, 255, 255, 0.95);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  border-radius: 4px;
}

.no-account-message {
  text-align: center;
  color: #856404;
  padding: 40px;
}

.no-account-message i {
  font-size: 48px;
  margin-bottom: 20px;
  color: #ffc107;
}

.no-account-message h3 {
  font-size: 28px;
  font-weight: bold;
  margin-bottom: 10px;
  color: #333;
}

.no-account-message p {
  font-size: 16px;
  color: #666;
  margin: 0;
}

@media print {
  .drawing-element {
    z-index: 5;
  }
  
  .no-account-overlay {
    display: none !important;
  }
  
  /* Reset scaling for print */
  .check-box {
    transform: none !important;
  }
  
  /* Ensure MICR font is applied in print */
  .banking {
    font-family: 'banking' !important;
    font-size: 37px !important;
  }
}

label {
    font-weight: bold;
}
.memo-data {
    font-family: Caveat;
    font-size: 30px;
    max-width: 350px;
    line-height: 0.65;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
}
.signature-data {
    font-family: Caveat;
    font-size: 40px;
    transform: rotate(-2deg);
}

/* Stub content styles */
.stub-content {
    font-family: Arial, sans-serif;
    font-size: 12px;
    line-height: 1.4;
}

.stub-header {
    font-weight: bold;
    font-size: 14px;
    margin-bottom: 10px;
    border-bottom: 1px solid #ccc;
    padding-bottom: 5px;
}
.amount-line-data {
    text-transform: capitalize;
}
.date-data, .pay-to-data, .amount-data{
    font-size: 20px;
    font-weight: bold;
}
.check-data {
    margin-top: 50px;
    padding: 50px 120px;
    border-top: 1px solid #e6e6e6;
}
.bank-name{
    font-size: 20px;
    font-weight: bold;
}
.account-holder-name {
    font-size: 20px;
    font-weight: bold;
}
.check-number-human {
    font-size: 20px;
    font-weight: bold;
}
.amount-box::before {
    content: "$";
    font-size: 20px;
    margin-left: -15px;
    font-weight: bold;
}
.amount-box {
    width: 225px;
    height: 40px;
    border: 1px solid #c7c7c7;
    background-color: white;
}
.wrapper {
    display: flex;
    justify-content: center;
    width: 100%;
    padding: 20px;
    box-sizing: border-box;
}

.check-box {
    width: 1200px;
    height: 1480px;
    max-width: 100%;
    border: 1px solid #e6e6e6;
    background-color: white;
    margin: 0 auto;
    background: url('../assets/checkbg.png');
    background-repeat: no-repeat;
    background-size: 1200px 410px;
    background-position: center top;
    transform-origin: top center;
    margin: 0 auto;
}

#check-box {
    width: 100%;
}

#check-box-print {
    position: relative !important;
    width: 100%;
    height: 100%;
}

/* Responsive scaling - maintain aspect ratio */
@media (max-width: 1240px) {
    .check-box {
        width: calc(100vw - 40px);
        height: calc((100vw - 40px) * 1.294);
    }
}

@media (min-width: 1241px) {
    .wrapper {
        max-width: 1240px;
        margin: 0 auto;
    }
}

@font-face {
    font-family: 'banking';
    src: url('../assets/micrenc.ttf');
}


.banking {
    font-family: 'banking';
    font-size: 37px;
}
.dollar-line::after{
    content: "Dollars";
    font-size: 18px;
    position: absolute;
    right: -73px;
    top: 0;
}
.dollar-line {
    width: 840px;
    display: block;
    border-bottom: 1px solid black;
    margin-left: 10px;
    margin-top: 20px;
}
.payto-line {
    width: 776px;
    display: block;
    border-bottom: 1px solid black;
    margin-left: 73px;
    border-right: 1px solid black;
    height: 28px;
    margin-top: -32px;
}
</style>
