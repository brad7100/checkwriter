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
                                        <span v-if="unpCheck.status === 'pending'" class="badge bg-warning text-dark me-2">Pending</span>
                                        <button v-if="unpCheck.status === 'pending' && state.canApproveChecks" 
                                                class="btn btn-sm btn-success me-1" 
                                                @click="approveCheckForPrinting(unpCheck)"
                                                title="Approve this check for printing">
                                            <i class="bi bi-check-circle-fill"></i> Approve
                                        </button>
                                        <button v-if="unpCheck.status === 'pending' && state.canApproveChecks" 
                                                class="btn btn-sm btn-danger me-1" 
                                                @click="rejectCheckForPrinting(unpCheck)"
                                                title="Reject this check">
                                            <i class="bi bi-x-circle-fill"></i> Reject
                                        </button>
                                        <button class="btn btn-sm btn-primary me-1" 
                                                @click="loadCheckForEditing(unpCheck)"
                                                title="Edit and print">
                                            <i class="bi bi-pencil"></i> Edit
                                        </button>
                                        <button class="btn btn-sm btn-success me-1" 
                                                @click="printCheckDirectly(unpCheck)"
                                                :disabled="unpCheck.status === 'pending'"
                                                :title="unpCheck.status === 'pending' ? 'Check must be approved before printing' : 'Print as-is'">
                                            <i class="bi bi-printer"></i> Print
                                        </button>
                                        <button class="btn btn-sm btn-outline-secondary" 
                                                @click="markAsPrinted(unpCheck)"
                                                :disabled="unpCheck.status === 'pending'"
                                                :title="unpCheck.status === 'pending' ? 'Check must be approved before marking as printed' : 'Mark as printed without printing'">
                                            <i class="bi bi-check-circle"></i> Mark Printed
                                        </button>
                                    </td>
                                </tr>
                            </tbody>
                        </table>
                    </div>
                    <div style="margin-top: 12px;">
                        <button class="btn btn-success me-2" 
                                @click="batchPrintUnprinted" 
                                :disabled="unprintedChecks.length === 0 || approvedChecksCount === 0"
                                :title="approvedChecksCount === 0 ? 'No approved checks to print' : `Print ${approvedChecksCount} approved check(s)`">
                            <i class="bi bi-printer-fill"></i> Batch Print Approved ({{ approvedChecksCount }})
                        </button>
                        <button class="btn btn-outline-secondary" 
                                @click="markSelectedAsPrinted" 
                                :disabled="selectedCheckIds.length === 0"
                                title="Mark selected checks as printed without printing">
                            <i class="bi bi-check-circle-fill"></i> Mark Selected as Printed ({{ selectedCheckIds.length }})
                        </button>
                        <div v-if="hasPendingChecks" class="alert alert-info mt-2 mb-0" style="font-size: 13px;">
                            <i class="bi bi-info-circle"></i> 
                            {{ pendingChecksCount }} check(s) pending approval. Batch print will only print approved checks.
                        </div>
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

// Check counts for batch printing
const hasPendingChecks = computed(() => 
  unprintedChecks.value.some(c => c.status === 'pending')
)

const pendingChecksCount = computed(() => 
  unprintedChecks.value.filter(c => c.status === 'pending').length
)

const approvedChecksCount = computed(() => 
  unprintedChecks.value.filter(c => c.status === 'approved').length
)

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
    // Validate that company and account are selected
    if (!state.selectedCompanyId || !state.selectedAccountId) {
        alert('Please select a company and bank account before printing.')
        return
    }
    
    // Validate check data
    if (!check.companyId || !check.accountId) {
        alert('Check data is incomplete. Please refresh the page and select a company and account.')
        return
    }
    
    // Always save the check first (create or update)
    try {
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
    } catch (error) {
        console.error('Error saving check:', error)
        alert(`Failed to save check: ${error.message || 'Unknown error'}`)
        return
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
    // Validate that company and account are selected
    if (!state.selectedCompanyId || !state.selectedAccountId) {
        alert('Please select a company and bank account before saving.')
        return
    }
    
    // Validate check data
    if (!check.companyId || !check.accountId) {
        alert('Check data is incomplete. Please refresh the page and select a company and account.')
        return
    }
    
    try {
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
    } catch (error) {
        console.error('Error saving check:', error)
        alert(`Failed to save check: ${error.message || 'Unknown error'}`)
    }
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
    
    // Open print window synchronously (before any await) to avoid iOS Safari popup blocking
    const printWindow = window.open('', '_blank', 'width=850,height=1100')
    
    if (!printWindow) {
        alert('Pop-up blocked! Please allow pop-ups for this site to print checks.')
        return
    }
    
    try {
        // Generate the proper check HTML using the same template rendering as single print
        const checkHtml = await generatePrintableCheckHtml(checkToUse)
        printWindow.document.write(checkHtml)
        printWindow.document.close()
        
        // Mark as printed AFTER the print window has opened successfully
        checkToUse.isPrinted = true
        checkToUse.printedDate = new Date().toISOString()
        
        await state.updateCheck(checkToUse.id, checkToUse)
        
        // Set up print handler
        printWindow.onload = () => {
            printWindow.print()
            printWindow.close()
        }
        
        // Reload the unprinted queue
        await loadUnprintedChecks()
    } catch (error) {
        printWindow.close()
        console.error('Error printing check:', error)
        alert(`Failed to print check: ${error.message || 'Unknown error'}`)
    }
}

async function batchPrintUnprinted() {
    if (unprintedChecks.value.length === 0) return
    
    // Filter to only approved checks
    const approvedChecks = unprintedChecks.value.filter(c => c.status === 'approved')
    const pendingChecks = unprintedChecks.value.filter(c => c.status === 'pending')
    
    if (approvedChecks.length === 0) {
        alert('No approved checks to print.')
        return
    }
    
    let confirmMsg = `Print ${approvedChecks.length} approved check(s)?`
    if (pendingChecks.length > 0) {
        confirmMsg += `\n\n${pendingChecks.length} pending check(s) will be skipped.`
    }
    
    if (!confirm(confirmMsg)) return
    
    // Open print window synchronously (before any await) to avoid iOS Safari popup blocking
    const printWindow = window.open('', '_blank', 'width=850,height=1100')
    
    if (!printWindow) {
        alert('Pop-up blocked! Please allow pop-ups for this site to print checks.')
        return
    }
    
    try {
        // Generate combined HTML for approved checks using the proper template rendering
        let combinedHtml = '<html><head><style>@page { size: letter; margin: 0; } @media print { .page-break { page-break-after: always; } }</style></head><body>'
        
        for (let i = 0; i < approvedChecks.length; i++) {
            const checkData = approvedChecks[i]
            const checkHtml = await generatePrintableCheckHtml(checkData)
            combinedHtml += checkHtml
            if (i < approvedChecks.length - 1) {
                combinedHtml += '<div class="page-break"></div>'
            }
        }
        
        combinedHtml += '</body></html>'
        
        printWindow.document.write(combinedHtml)
        printWindow.document.close()
        
        // Mark approved checks as printed AFTER the print window has opened successfully
        const updates = approvedChecks.map(check => ({
            ...check,
            isPrinted: true,
            printedDate: new Date().toISOString()
        }))
        
        // Update all in database
        for (const checkToUpdate of updates) {
            await state.updateCheck(checkToUpdate.id, checkToUpdate)
        }
        
        // Set up print handler
        printWindow.onload = () => {
            printWindow.print()
            printWindow.close()
        }
        
        // Reload the unprinted queue
        await loadUnprintedChecks()
        
        // Show success message with information about skipped checks
        let successMsg = `Successfully printed ${approvedChecks.length} check(s).`
        if (pendingChecks.length > 0) {
            successMsg += `\n\n${pendingChecks.length} pending check(s) were skipped and remain in the queue.`
        }
        alert(successMsg)
    } catch (error) {
        printWindow.close()
        console.error('Error batch printing checks:', error)
        alert(`Failed to batch print checks: ${error.message || 'Unknown error'}`)
        // Reload the queue anyway to show current state
        await loadUnprintedChecks()
    }
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

async function approveCheckForPrinting(unpCheck) {
    if (!state.canApproveChecks) {
        alert('Only approvers and admins can approve checks.')
        return
    }
    
    const confirmMsg = `Approve check #${unpCheck.checkNumber} to ${unpCheck.payTo} for $${formatMoney(unpCheck.amount)}?`
    if (!confirm(confirmMsg)) return
    
    try {
        await state.approveCheck(unpCheck.id)
        
        // Reload the unprinted queue to show updated status
        await loadUnprintedChecks()
        
        alert(`Check #${unpCheck.checkNumber} approved successfully!`)
    } catch (error) {
        console.error('Error approving check:', error)
        alert(`Failed to approve check: ${error.message}`)
    }
}

async function rejectCheckForPrinting(unpCheck) {
    if (!state.canApproveChecks) {
        alert('Only approvers and admins can reject checks.')
        return
    }
    
    const confirmMsg = `Reject check #${unpCheck.checkNumber} to ${unpCheck.payTo} for $${formatMoney(unpCheck.amount)}?\n\nThis check will be removed from the Ready to Print queue.`
    if (!confirm(confirmMsg)) return
    
    try {
        await state.rejectCheck(unpCheck.id)
        
        // Reload the unprinted queue to show updated status
        await loadUnprintedChecks()
        
        alert(`Check #${unpCheck.checkNumber} rejected.`)
    } catch (error) {
        console.error('Error rejecting check:', error)
        alert(`Failed to reject check: ${error.message}`)
    }
}

// Helper to generate proper check HTML for printing using the same template rendering as single print
async function generatePrintableCheckHtml(checkData) {
    // This function generates HTML that matches the exact format of single-check printing
    // It uses the same template logic, positioning, fonts, MICR line, etc.
    
    const toWords = new ToWords({
        localeCode: 'en-US',
        converterOptions: {
            currency: true,
            ignoreDecimal: false,
            ignoreZeroCurrency: false,
            doNotAddOnly: true,
        }
    })
    
    const amount = Number(checkData.amount || 0)
    const dollars = Math.floor(amount)
    const cents = Math.round((amount - dollars) * 100)
    const dollarsWords = dollars === 0 ? 'Zero' : toWords.convert(dollars)
    const centsStr = cents.toString().padStart(2, '0')
    const amountWords = `*** ${dollarsWords} and ${centsStr}/100 Dollars ***`
    
    // Get the current template (same logic as in the component)
    let templateToUse = null
    if (isPreprinted.value) {
        templateToUse = state.customLayouts.find(layout => layout.name === 'preprinted')
    } else if (selectedTemplateId.value !== 'original') {
        templateToUse = state.customLayouts.find(layout => layout.id === selectedTemplateId.value)
    }
    
    // Helper function to get field content for a check
    const getFieldContentForCheck = (field, checkData) => {
        if (!field.dataBinding) {
            return field.text || ''
        }
        
        switch (field.dataBinding) {
            case 'accountHolderName':
                return checkData.accountHolderName || state.selectedCompany?.name || ''
            case 'accountHolderAddress':
                return checkData.accountHolderAddress || state.selectedCompany?.address || ''
            case 'accountHolderCity':
                return checkData.accountHolderCity || state.selectedCompany?.city || ''
            case 'accountHolderState':
                return checkData.accountHolderState || state.selectedCompany?.state || ''
            case 'accountHolderZip':
                return checkData.accountHolderZip || state.selectedCompany?.zip || ''
            case 'accountHolderCityStateZip':
            case 'accountHolderCityState':
                return `${checkData.accountHolderCity || state.selectedCompany?.city || ''}, ${checkData.accountHolderState || state.selectedCompany?.state || ''} ${checkData.accountHolderZip || state.selectedCompany?.zip || ''}`
            case 'checkNumber':
                return checkData.checkNumber
            case 'date':
                return checkData.date
            case 'amount':
                return '$ ' + formatMoney(checkData.amount)
            case 'amountWords':
                return amountWords
            case 'payTo':
                return checkData.payTo
            case 'bankName':
                return checkData.bankName
            case 'memo':
                return checkData.memo || ''
            case 'signature':
                return checkData.signature
            case 'routingNumber':
                return checkData.routingNumber
            case 'mailToAddress':
            case 'payeeAddress':
                return checkData.mailToAddress || ''
            case 'mailToCity':
                return checkData.mailToCity || ''
            case 'mailToState':
                return checkData.mailToState || ''
            case 'mailToZip':
                return checkData.mailToZip || ''
            case 'mailToCityStateZip':
            case 'payeeCityStateZip':
                return `${checkData.mailToCity || ''}, ${checkData.mailToState || ''} ${checkData.mailToZip || ''}`.trim()
            default:
                return ''
        }
    }
    
    let checkContent = ''
    
    // If using a custom template, render fields and drawing elements
    if (templateToUse && templateToUse.fields) {
        templateToUse.fields.forEach(field => {
            // Skip MICR, routing, and check number if preprinted
            if (isPreprinted.value && (field.id === 'micr-line' || field.id === 'routingNumber' || field.id === 'checkNumber')) {
                return
            }
            
            const content = getFieldContentForCheck(field, checkData)
            const style = `position: absolute; left: ${field.x}px; top: ${field.y}px; width: ${field.width}px; height: ${field.height}px; font-family: ${field.fontFamily}; font-size: ${field.fontSize}px; font-weight: ${field.fontWeight ? 'bold' : 'normal'}; font-style: ${field.fontStyle ? 'italic' : 'normal'}; color: ${field.color}; text-align: ${field.textAlign || 'left'}; white-space: pre-line;`
            checkContent += `<div style="${style}">${content}</div>`
        })
        
        if (templateToUse.drawingElements) {
            templateToUse.drawingElements.forEach(element => {
                let style = `position: absolute; left: ${element.x}px; top: ${element.y}px; width: ${element.width}px; height: ${element.height}px;`
                
                if (element.type === 'line') {
                    style += `border: none; border-top: ${element.strokeWidth || 2}px solid ${element.strokeColor || '#000'}; background: transparent;`
                } else {
                    style += `border: ${element.strokeWidth}px solid ${element.strokeColor}; background-color: ${element.fillColor || 'transparent'};`
                    if (element.rotation) {
                        style += `transform: rotate(${element.rotation}deg); transform-origin: center;`
                    }
                }
                
                checkContent += `<div style="${style}"></div>`
            })
        }
    } else {
        // Use original template layout
        checkContent = `
            <div style="position: absolute; top: 40px; left: 60px; font-size: 20px; font-weight: bold;">${checkData.accountHolderName}</div>
            <div style="position: absolute; top: 70px; left: 60px;">
                ${checkData.accountHolderAddress}<br>
                ${checkData.accountHolderCity}, ${checkData.accountHolderState} ${checkData.accountHolderZip}
            </div>
            <div style="position: absolute; top: 40px; left: 1060px; font-size: 20px; font-weight: bold;">${checkData.checkNumber}</div>
            <div style="position: absolute; top: 80px; left: 850px; font-size: 20px; font-weight: bold;">${checkData.date}</div>
            <div style="position: absolute; top: 90px; left: 760px;">Date: _____________________ </div>
            <div style="position: absolute; top: 175px; left: 950px; width: 225px; height: 40px; border: 1px solid #c7c7c7; background-color: white;"></div>
            <div style="position: absolute; top: 182px; left: 970px; font-size: 20px; font-weight: bold;">$ ${formatMoney(checkData.amount)}</div>
            <div style="position: absolute; top: 180px; left: 180px; font-size: 20px; font-weight: bold;">${checkData.payTo}</div>
            <div style="position: absolute; top: 170px; left: 60px;">Pay to the <br>Order of</div>
            <div style="position: absolute; top: 240px; left: 100px; text-transform: capitalize;">${amountWords}</div>
            <div style="position: absolute; top: 300px; left: 60px; font-size: 20px; font-weight: bold;">${checkData.bankName}</div>
            <div style="position: absolute; top: 367px; left: 120px; font-family: Caveat, cursive; font-size: 30px; max-width: 350px;">${checkData.memo || ''}</div>
            <div style="position: absolute; top: 390px; left: 60px;">Memo: ____________________________________</div>
            <div style="position: absolute; top: 366px; left: 770px; font-family: Caveat, cursive; font-size: 40px; transform: rotate(-2deg);">${checkData.signature}</div>
            <div style="position: absolute; top: 390px; left: 750px;">_________________________________________________</div>
        `
    }
    
    // Add MICR line if not preprinted
    let micrLine = ''
    if (!isPreprinted.value) {
        micrLine = `<div style="position: absolute; top: 420px; left: 147px; font-family: 'banking', monospace; font-size: 37px;">a${checkData.routingNumber}a ${checkData.bankAccountNumber}c ${checkData.checkNumber}</div>`
    }
    
    // Generate stub HTML
    const stubContent = currentStubTemplate.value 
        ? generateStubHtmlForCheck(checkData, currentStubTemplate.value)
        : generateDefaultStubHtml(checkData)
    
    // Return complete HTML document
    return `
        <div style="width: 1200px; min-height: 1480px; position: relative; background: white;">
            <div style="position: relative; width: 100%; height: 410px;">
                ${checkContent}
                ${micrLine}
            </div>
            ${stubContent}
        </div>
    `
}

// Helper to generate stub HTML for custom template
function generateStubHtmlForCheck(checkData, template) {
    let stub1Content = ''
    let stub2Content = ''
    
    if (template.fields) {
        template.fields.forEach(field => {
            const content = field.text || '' // Stub templates usually use static text
            const style = `position: absolute; left: ${field.x}px; top: ${field.y}px; width: ${field.width}px; height: ${field.height}px; font-family: ${field.fontFamily}; font-size: ${field.fontSize}px; font-weight: ${field.fontWeight ? 'bold' : 'normal'}; color: ${field.color};`
            stub1Content += `<div style="${style}">${content}</div>`
            stub2Content += `<div style="${style}">${content}</div>`
        })
    }
    
    return `
        <div style="position: absolute; top: 525px; left: 150px; width: 612px; height: 300px; border: 1px solid #ccc; background: white; padding: 20px; transform: scale(1.5); transform-origin: top left;">
            ${stub1Content}
        </div>
        <div style="position: absolute; top: 1000px; left: 150px; width: 612px; height: 300px; border: 1px solid #ccc; background: white; padding: 20px; transform: scale(1.5); transform-origin: top left;">
            ${stub2Content}
        </div>
    `
}

// Helper to generate default stub HTML
function generateDefaultStubHtml(checkData) {
    const stub1 = `
        <div style="font-family: Arial, sans-serif; font-size: 12px;">
            <div style="font-weight: bold; font-size: 14px; margin-bottom: 10px; border-bottom: 1px solid #ccc; padding-bottom: 5px;">Check Stub - Payee Copy</div>
            <div><strong>Company:</strong> ${state.selectedCompany?.name || 'N/A'}</div>
            <div><strong>Account:</strong> ${state.selectedAccount?.name || 'N/A'}</div>
            <div><strong>Check #:</strong> ${checkData.checkNumber}</div>
            <div><strong>Date:</strong> ${checkData.date}</div>
            <div><strong>Pay to:</strong> ${checkData.payTo}</div>
            <div><strong>Amount:</strong> $${formatMoney(checkData.amount)}</div>
            <div><strong>Memo:</strong> ${checkData.memo || ''}</div>
        </div>
    `
    
    const stub2 = `
        <div style="font-family: Arial, sans-serif; font-size: 12px;">
            <div style="font-weight: bold; font-size: 14px; margin-bottom: 10px; border-bottom: 1px solid #ccc; padding-bottom: 5px;">Check Stub - Bank Copy</div>
            <div><strong>Company:</strong> ${state.selectedCompany?.name || 'N/A'}</div>
            <div><strong>Account:</strong> ${state.selectedAccount?.name || 'N/A'}</div>
            <div><strong>Check #:</strong> ${checkData.checkNumber}</div>
            <div><strong>Date:</strong> ${checkData.date}</div>
            <div><strong>Pay to:</strong> ${checkData.payTo}</div>
            <div><strong>Amount:</strong> $${formatMoney(checkData.amount)}</div>
            <div><strong>Memo:</strong> ${checkData.memo || ''}</div>
            <div><strong>Routing:</strong> ${checkData.routingNumber}</div>
            <div><strong>Account #:</strong> ${checkData.bankAccountNumber}</div>
        </div>
    `
    
    return `
        <div style="position: absolute; top: 525px; left: 150px; width: 612px; height: 300px; border: 1px solid #ccc; background: white; padding: 20px; transform: scale(1.5); transform-origin: top left; box-sizing: border-box;">
            ${stub1}
        </div>
        <div style="position: absolute; top: 1000px; left: 150px; width: 612px; height: 300px; border: 1px solid #ccc; background: white; padding: 20px; transform: scale(1.5); transform-origin: top left; box-sizing: border-box;">
            ${stub2}
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
    companyId: state.selectedCompanyId || '',
    accountId: state.selectedAccountId || '',
    accountHolderName: '',
    accountHolderAddress: '',
    accountHolderCity: '',
    accountHolderState: '',
    accountHolderZip: '',
    checkNumber: '1000',
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
        // Fallback: Generate a new check (will have empty IDs until account is selected)
        const newCheck = await genNewCheck()
        Object.assign(check, newCheck)
    }
    
    // Ensure companyId and accountId are set if company/account are selected
    if (state.selectedCompanyId && !check.companyId) {
        check.companyId = state.selectedCompanyId
    }
    if (state.selectedAccountId && !check.accountId) {
        check.accountId = state.selectedAccountId
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
    console.log('🔄 Account selection changed - CompanyID:', state.selectedCompanyId, 'AccountID:', state.selectedAccountId)
    
    // Reload unprinted checks when account changes
    await loadUnprintedChecks()
    
    if (state.selectedCompany && state.selectedAccount) {
        console.log('✅ Company and Account loaded:', {
            company: state.selectedCompany.name,
            account: state.selectedAccount.name,
            routingNumber: state.selectedAccount.routingNumber,
            accountNumber: state.selectedAccount.accountNumber
        })
        
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
        
        console.log('✅ Check populated with routing number:', check.routingNumber)
        
        // Update check number for the newly selected account (await async call)
        check.checkNumber = await getNextCheckNumber(state.selectedAccountId)
        console.log('✅ Check number assigned:', check.checkNumber)
        
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
        console.log('⚠️ Company or Account not fully loaded yet')
        if (!state.selectedCompany) console.log('  - Missing company')
        if (!state.selectedAccount) console.log('  - Missing account')
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
