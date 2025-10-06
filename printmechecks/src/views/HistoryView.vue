<template>
    <div class="about">
        <div class="d-flex justify-content-between align-items-center mb-4">
            <h1>Check History</h1>
            <div>
                <button class="btn btn-outline-secondary me-2" @click="selectAllUnprinted" v-if="unprintedChecks.length > 0">
                    Select All Unprinted
                </button>
                <button class="btn btn-primary" @click="batchPrintSelected" v-if="selectedChecks.length > 0">
                    <i class="bi bi-printer"></i> Print Selected ({{ selectedChecks.length }})
                </button>
            </div>
        </div>

        <!-- Search and Filters -->
        <div class="row mb-3">
            <div class="col-md-6">
                <label class="form-label"><strong>Quick Search:</strong></label>
                <div class="input-group">
                    <input 
                        type="text" 
                        class="form-control" 
                        v-model="quickSearch" 
                        placeholder="Search by date, amount, payee, memo..."
                    >
                    <button class="btn btn-outline-secondary" type="button" @click="clearQuickSearch">
                        <i class="bi bi-x"></i>
                    </button>
                </div>
            </div>
            <div class="col-md-3">
                <label class="form-label"><strong>Filter by Account:</strong></label>
                <select class="form-select" v-model="filterAccountId">
                    <option value="">All Accounts</option>
                    <option v-for="account in store.bankAccounts" :key="account.id" :value="account.id">
                        {{ account.name }} ({{ account.bankName }})
                    </option>
                </select>
            </div>
            <div class="col-md-3 d-flex align-items-end">
                <button class="btn btn-outline-primary" @click="showAdvancedSearch = true">
                    <i class="bi bi-search"></i> Advanced Search
                </button>
            </div>
        </div>

        <!-- Search Results Info -->
        <div v-if="history.length > 0" class="mb-3">
            <small class="text-muted">
                Showing {{ filteredHistory.length }} of {{ history.length }} checks
                <span v-if="quickSearch || hasAdvancedSearch">
                    (filtered)
                </span>
            </small>
        </div>

        <div v-if="filteredHistory.length === 0">
            <div class="alert alert-info">
                <i class="bi bi-info-circle"></i>
                <span v-if="history.length === 0">No checks in history yet</span>
                <span v-else>No checks match your search criteria</span>
            </div>
        </div>
        <div v-else>
            <table class="table table-hover">
                <thead>
                    <tr>
                        <th style="width: 40px;">
                            <input 
                                type="checkbox" 
                                class="form-check-input"
                                @click.stop
                                @change="toggleSelectAll"
                                :checked="isAllSelected"
                                title="Select All"
                            >
                        </th>
                        <th>Check #</th>
                        <th>Date</th>
                        <th>Amount</th>
                        <th>Payee</th>
                        <th>Account</th>
                        <th>Memo</th>
                        <th>Status</th>
                        <th style="width: 150px;">Actions</th>
                    </tr>
                </thead>
                <tbody>
                    <tr v-for="(item, index) in filteredHistory" :key="item.id" :class="{ 'table-success': item.isPrinted, 'table-info': isSelected(item.id) }" @dblclick="viewItem(item)" title="Double-click to view/edit check">
                        <td @click.stop>
                            <input 
                                type="checkbox" 
                                class="form-check-input"
                                :checked="isSelected(item.id)"
                                @click.stop
                                @change="toggleCheckSelection(item.id)"
                            >
                        </td>
                        <td>{{ item.checkNumber }}</td>
                        <td>{{ item.date }}</td>
                        <td>${{ formatMoney(item.amount) }}</td>
                        <td>{{ item.payTo }}</td>
                        <td>{{ getAccountName(item.accountId) }}</td>
                        <td>{{ item.memo || '-' }}</td>
                        <td>
                            <span v-if="item.isPrinted" class="badge bg-success">
                                <i class="bi bi-check-circle"></i> Printed
                            </span>
                            <span v-else class="badge bg-warning text-dark">
                                <i class="bi bi-clock"></i> Unprinted
                            </span>
                        </td>
                        <td @click.stop>
                            <div class="btn-group btn-group-sm" role="group">
                                <button class="btn btn-outline-primary" @click="viewItem(item)" title="View/Edit">
                                    <i class="bi bi-eye"></i>
                                </button>
                                <button class="btn btn-outline-success" @click="printSingleCheck(item)" title="Print">
                                    <i class="bi bi-printer"></i>
                                </button>
                                <button class="btn btn-outline-danger" @click="deleteItem(item.id)" title="Delete">
                                    <i class="bi bi-trash"></i>
                                </button>
                            </div>
                        </td>
                    </tr>
                </tbody>
            </table>
        </div>

        <!-- Advanced Search Modal -->
        <div class="modal fade" :class="{ show: showAdvancedSearch }" :style="{ display: showAdvancedSearch ? 'block' : 'none' }" tabindex="-1">
            <div class="modal-dialog modal-lg">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title">Advanced Search</h5>
                        <button type="button" class="btn-close" @click="showAdvancedSearch = false"></button>
                    </div>
                    <div class="modal-body">
                        <div class="row">
                            <div class="col-md-6 mb-3">
                                <label class="form-label">Check Number</label>
                                <input type="text" class="form-control" v-model="advancedSearch.checkNumber" placeholder="e.g., 1001">
                            </div>
                            <div class="col-md-6 mb-3">
                                <label class="form-label">Date From</label>
                                <input type="date" class="form-control" v-model="advancedSearch.dateFrom">
                            </div>
                            <div class="col-md-6 mb-3">
                                <label class="form-label">Date To</label>
                                <input type="date" class="form-control" v-model="advancedSearch.dateTo">
                            </div>
                            <div class="col-md-6 mb-3">
                                <label class="form-label">Amount From</label>
                                <input type="number" class="form-control" v-model="advancedSearch.amountFrom" step="0.01" placeholder="0.00">
                            </div>
                            <div class="col-md-6 mb-3">
                                <label class="form-label">Amount To</label>
                                <input type="number" class="form-control" v-model="advancedSearch.amountTo" step="0.01" placeholder="0.00">
                            </div>
                            <div class="col-md-6 mb-3">
                                <label class="form-label">Payee</label>
                                <input type="text" class="form-control" v-model="advancedSearch.payee" placeholder="Payee name">
                            </div>
                            <div class="col-md-6 mb-3">
                                <label class="form-label">Memo</label>
                                <input type="text" class="form-control" v-model="advancedSearch.memo" placeholder="Memo text">
                            </div>
                            <div class="col-md-6 mb-3">
                                <label class="form-label">Account</label>
                                <select class="form-select" v-model="advancedSearch.accountId">
                                    <option value="">All Accounts</option>
                                    <option v-for="account in store.bankAccounts" :key="account.id" :value="account.id">
                                        {{ account.name }} ({{ account.bankName }})
                                    </option>
                                </select>
                            </div>
                            <div class="col-md-6 mb-3">
                                <label class="form-label">Status</label>
                                <select class="form-select" v-model="advancedSearch.status">
                                    <option value="">All Status</option>
                                    <option value="printed">Printed</option>
                                    <option value="unprinted">Unprinted</option>
                                </select>
                            </div>
                        </div>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" @click="clearAdvancedSearch">Clear All</button>
                        <button type="button" class="btn btn-primary" @click="applyAdvancedSearch">Search</button>
                    </div>
                </div>
            </div>
        </div>
        <div v-if="showAdvancedSearch" class="modal-backdrop fade show"></div>
    </div>
</template>

<style scoped>
tbody tr {
    cursor: pointer;
    transition: background-color 0.2s ease;
}

tbody tr:hover {
    background-color: #f8f9fa !important;
}

tbody tr.table-info {
    background-color: #cfe2ff !important;
}

tbody tr.table-info:hover {
    background-color: #b3d9ff !important;
}
</style>

<script setup lang="ts">
import { formatMoney } from '../utilities.ts'
import { ref, onMounted, computed } from 'vue'
import { useAppStore } from '../stores/app.ts'
import { useRouter } from 'vue-router'
import type { Check } from '../stores/app'
import { supabase } from '../lib/supabase'

const store = useAppStore()
const router = useRouter()

const history = ref<Check[]>([])
const selectedChecks = ref<string[]>([])
const filterAccountId = ref('')
const quickSearch = ref('')
const showAdvancedSearch = ref(false)
const advancedSearch = ref({
    checkNumber: '',
    dateFrom: '',
    dateTo: '',
    amountFrom: '',
    amountTo: '',
    payee: '',
    memo: '',
    accountId: '',
    status: ''
})

const loadHistory = async () => {
  history.value = await store.getChecks()
}

const filteredHistory = computed(() => {
  let filtered = history.value

  // Apply account filter
  if (filterAccountId.value) {
    filtered = filtered.filter(check => check.accountId === filterAccountId.value)
  }

  // Apply quick search
  if (quickSearch.value.trim()) {
    const searchTerm = quickSearch.value.toLowerCase().trim()
    filtered = filtered.filter(check => {
      return (
        check.checkNumber?.toString().toLowerCase().includes(searchTerm) ||
        check.date?.toLowerCase().includes(searchTerm) ||
        check.amount?.toString().toLowerCase().includes(searchTerm) ||
        check.payTo?.toLowerCase().includes(searchTerm) ||
        check.memo?.toLowerCase().includes(searchTerm) ||
        getAccountName(check.accountId).toLowerCase().includes(searchTerm)
      )
    })
  }

  // Apply advanced search filters
  if (advancedSearch.value.checkNumber) {
    filtered = filtered.filter(check => 
      check.checkNumber?.toString().includes(advancedSearch.value.checkNumber)
    )
  }

  if (advancedSearch.value.dateFrom) {
    filtered = filtered.filter(check => {
      const checkDate = new Date(check.date)
      const fromDate = new Date(advancedSearch.value.dateFrom)
      return checkDate >= fromDate
    })
  }

  if (advancedSearch.value.dateTo) {
    filtered = filtered.filter(check => {
      const checkDate = new Date(check.date)
      const toDate = new Date(advancedSearch.value.dateTo)
      return checkDate <= toDate
    })
  }

  if (advancedSearch.value.amountFrom) {
    filtered = filtered.filter(check => 
      parseFloat(check.amount) >= parseFloat(advancedSearch.value.amountFrom)
    )
  }

  if (advancedSearch.value.amountTo) {
    filtered = filtered.filter(check => 
      parseFloat(check.amount) <= parseFloat(advancedSearch.value.amountTo)
    )
  }

  if (advancedSearch.value.payee) {
    filtered = filtered.filter(check => 
      check.payTo?.toLowerCase().includes(advancedSearch.value.payee.toLowerCase())
    )
  }

  if (advancedSearch.value.memo) {
    filtered = filtered.filter(check => 
      check.memo?.toLowerCase().includes(advancedSearch.value.memo.toLowerCase())
    )
  }

  if (advancedSearch.value.accountId) {
    filtered = filtered.filter(check => check.accountId === advancedSearch.value.accountId)
  }

  if (advancedSearch.value.status) {
    if (advancedSearch.value.status === 'printed') {
      filtered = filtered.filter(check => check.isPrinted)
    } else if (advancedSearch.value.status === 'unprinted') {
      filtered = filtered.filter(check => !check.isPrinted)
    }
  }

  return filtered
})

const unprintedChecks = computed(() => {
  return filteredHistory.value.filter(check => !check.isPrinted)
})

const hasAdvancedSearch = computed(() => {
  return Object.values(advancedSearch.value).some(value => value !== '')
})

const isAllSelected = computed(() => {
  return filteredHistory.value.length > 0 && 
         filteredHistory.value.every(check => selectedChecks.value.includes(check.id || ''))
})

const isSelected = (checkId: string | undefined) => {
  return checkId ? selectedChecks.value.includes(checkId) : false
}

const toggleCheckSelection = (checkId: string | undefined) => {
  if (!checkId) return
  
  const index = selectedChecks.value.indexOf(checkId)
  if (index > -1) {
    selectedChecks.value.splice(index, 1)
  } else {
    selectedChecks.value.push(checkId)
  }
}

const toggleSelectAll = () => {
  if (isAllSelected.value) {
    // Deselect all
    selectedChecks.value = []
  } else {
    // Select all visible checks
    selectedChecks.value = filteredHistory.value.map(check => check.id || '').filter(id => id)
  }
}

const selectAllUnprinted = () => {
  selectedChecks.value = unprintedChecks.value.map(check => check.id || '').filter(id => id)
}

const getAccountName = (accountId: string) => {
  const account = store.bankAccounts.find(a => a.id === accountId)
  return account ? account.name : 'Unknown'
}

const clearQuickSearch = () => {
  quickSearch.value = ''
}

const clearAdvancedSearch = () => {
  advancedSearch.value = {
    checkNumber: '',
    dateFrom: '',
    dateTo: '',
    amountFrom: '',
    amountTo: '',
    payee: '',
    memo: '',
    accountId: '',
    status: ''
  }
}

const applyAdvancedSearch = () => {
  showAdvancedSearch.value = false
}


const deleteItem = async (checkId: string | undefined) => {
  if (!checkId) return
  if (!confirm('Are you sure you want to delete this check?')) return
  
  try {
    // Delete from Supabase
    const { error } = await supabase
      .from('checks')
      .delete()
      .eq('id', checkId)
    
    if (error) throw error
    
    // Remove from local state
    const index = history.value.findIndex(c => c.id === checkId)
    if (index > -1) {
      history.value.splice(index, 1)
      
      // Remove from selection if it was selected
      const selIndex = selectedChecks.value.indexOf(checkId)
      if (selIndex > -1) {
        selectedChecks.value.splice(selIndex, 1)
      }
    }
  } catch (error) {
    console.error('Error deleting check:', error)
    alert('Failed to delete check. Please check your connection.')
  }
}

const viewItem = (item: Check) => {
    // Set the check data
    store.check = item
    
    // Set the selected company and account based on the check's data
    if (item.companyId) {
        store.selectedCompanyId = item.companyId
    }
    if (item.accountId) {
        store.selectedAccountId = item.accountId
    }
    
    // Save the selections to localStorage
    store.saveData()
    
    router.push('/')
}

const printSingleCheck = async (item: Check) => {
  // Mark as printed
  item.isPrinted = true
  item.printedDate = new Date().toISOString()
  
  // Update in Supabase
  if (item.id) {
    await store.updateCheck(item.id, {
      isPrinted: true,
      printedDate: item.printedDate
    })
  }
  
  const index = history.value.findIndex(c => c.id === item.id)
  if (index > -1) {
    history.value[index] = item
  }
  
  // Store in state and navigate to print
  store.check = item
  
  // Set the selected company and account based on the check's data
  if (item.companyId) {
    store.selectedCompanyId = item.companyId
  }
  if (item.accountId) {
    store.selectedAccountId = item.accountId
  }
  
  // Save the selections to localStorage
  store.saveData()
  
  router.push('/')
  
  // Trigger print after navigation
  setTimeout(() => {
    window.print()
  }, 500)
}

const toWords = (amount: number | string): string => {
  const num = typeof amount === 'string' ? parseFloat(amount) : amount
  const dollars = Math.floor(num)
  const cents = Math.round((num - dollars) * 100)
  
  const ones = ['Zero', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine']
  const teens = ['Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen']
  const tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety']
  
  const convertLessThanThousand = (n: number): string => {
    if (n === 0) return ''
    if (n < 10) return ones[n]
    if (n < 20) return teens[n - 10]
    if (n < 100) {
      const ten = Math.floor(n / 10)
      const one = n % 10
      return tens[ten] + (one > 0 ? ' ' + ones[one] : '')
    }
    const hundred = Math.floor(n / 100)
    const rest = n % 100
    return ones[hundred] + ' Hundred' + (rest > 0 ? ' ' + convertLessThanThousand(rest) : '')
  }
  
  let result = ''
  if (dollars === 0) {
    result = 'Zero'
  } else if (dollars < 1000) {
    result = convertLessThanThousand(dollars)
  } else if (dollars < 1000000) {
    const thousands = Math.floor(dollars / 1000)
    const remainder = dollars % 1000
    result = convertLessThanThousand(thousands) + ' Thousand'
    if (remainder > 0) {
      result += ' ' + convertLessThanThousand(remainder)
    }
  }
  
  const centsStr = cents.toString().padStart(2, '0')
  return `*** ${result} and ${centsStr}/100 Dollars ***`
}

const batchPrintSelected = () => {
  const checksToPrint = history.value.filter(c => c.id && selectedChecks.value.includes(c.id))
  
  if (checksToPrint.length === 0) {
    alert('No checks selected for printing')
    return
  }
  
  // Open a new window for printing
  const printWindow = window.open('', '_blank')
  if (!printWindow) {
    alert('Please allow popups to print checks')
    return
  }
  
  // Build HTML for all checks
  let checksHtml = ''
  checksToPrint.forEach((check, index) => {
    const isLast = index === checksToPrint.length - 1
    checksHtml += `
      <div class="check-page" style="${!isLast ? 'page-break-after: always;' : ''}">
        <div class="check-box" style="width: 1200px; height: 1553px; border: 1px solid #e6e6e6; background-color: white; margin: 0 auto; background: url('data:image/svg+xml;utf8,<svg xmlns=&quot;http://www.w3.org/2000/svg&quot; width=&quot;1200&quot; height=&quot;410&quot;></svg>') no-repeat; background-size: 1200px 410px; position: relative;">
          <div class="account-holder-name" style="position: absolute; top: 40px; left: 60px; font-size: 20px; font-weight: bold;">${check.accountHolderName}</div>
          <div class="account-holder-address" style="position: absolute; top: 70px; left: 60px;">
            ${check.accountHolderAddress}<br>
            ${check.accountHolderCity}, ${check.accountHolderState} ${check.accountHolderZip}
          </div>
          <div class="check-number-human" style="position: absolute; top: 40px; left: 1060px; font-size: 20px; font-weight: bold;">${check.checkNumber}</div>
          <div class="date-data" style="position: absolute; top: 80px; left: 850px; font-size: 20px; font-weight: bold;">${check.date}</div>
          <div class="date" style="position: absolute; top: 90px; left: 760px;">Date: _____________________ </div>
          <div class="amount-box" style="position: absolute; top: 175px; left: 950px; width: 225px; height: 40px; border: 1px solid #c7c7c7; background-color: white; padding-left: 10px; line-height: 40px;">
            <span style="font-size: 20px; font-weight: bold;">$ ${formatMoney(check.amount)}</span>
          </div>
          <div class="pay-to-data" style="position: absolute; top: 180px; left: 180px; font-size: 20px; font-weight: bold;">${check.payTo}</div>
          <div class="pay-to" style="position: absolute; top: 170px; left: 60px;">
            Pay to the <br>Order of <span style="display: inline-block; width: 776px; border-bottom: 1px solid black; height: 28px;"></span>
          </div>
          <div class="amount-line-data" style="position: absolute; top: 240px; left: 100px; text-transform: capitalize;">
            ${toWords(check.amount)}
          </div>
          <div class="amount-line" style="position: absolute; top: 250px; left: 60px;">
            <span style="display: block; width: 840px; border-bottom: 1px solid black; margin-left: 10px; margin-top: 20px; position: relative;">
              <span style="position: absolute; right: -73px; top: 0; font-size: 18px;">Dollars</span>
            </span>
          </div>
          <div class="bank-name" style="position: absolute; top: 300px; left: 60px; font-size: 20px; font-weight: bold;">${check.bankName}</div>
          <div class="memo-data" style="position: absolute; top: 367px; left: 120px; font-family: Caveat, cursive; font-size: 30px; max-width: 350px;">${check.memo}</div>
          <div class="memo" style="position: absolute; top: 390px; left: 60px;">
            Memo: ____________________________________
          </div>
          <div class="signature-data" style="position: absolute; top: 366px; left: 770px; font-family: Caveat, cursive; font-size: 40px; transform: rotate(-2deg);">${check.signature}</div>
          <div class="signature" style="position: absolute; top: 390px; left: 750px;">
            _________________________________________________
          </div>
          <div class="banking" style="position: absolute; top: 420px; left: 80px; font-family: 'MICR', monospace; font-size: 37px;">
            a${check.routingNumber}a ${check.bankAccountNumber}c ${check.checkNumber}
          </div>
        </div>
      </div>
    `
  })
  
  // Write the HTML to the print window
  printWindow.document.write(`
    <!DOCTYPE html>
    <html>
    <head>
      <title>Print Checks</title>
      <style>
        @page {
          margin: 0;
          size: letter;
        }
        body {
          margin: 0;
          padding: 0;
          font-family: Arial, sans-serif;
        }
        .check-page {
          width: 100%;
          height: 100%;
        }
        @media print {
          .check-box {
            background: white !important;
          }
        }
      </style>
    </head>
    <body>
      ${checksHtml}
      <script>
        window.onload = function() {
          window.print();
          window.onafterprint = function() {
            window.close();
          };
        };
      <\/script>
    </body>
    </html>
  `)
  
  printWindow.document.close()
  
  // Mark all printed checks as printed
  checksToPrint.forEach(async (check) => {
    check.isPrinted = true
    check.printedDate = new Date().toISOString()
    
    // Update in Supabase
    if (check.id) {
      await store.updateCheck(check.id, {
        isPrinted: true,
        printedDate: check.printedDate
      })
    }
    
    const index = history.value.findIndex(c => c.id === check.id)
    if (index > -1) {
      history.value[index] = check
    }
  })
  
  // Clear selection
  selectedChecks.value = []
}

onMounted(() => {
  loadHistory()
})
</script>
