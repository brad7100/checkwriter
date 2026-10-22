<template>
  <div class="approval-queue-container">
    <div class="page-header">
      <h1>
        <i class="bi bi-check2-square"></i>
        Check Approval Queue
      </h1>
      <p class="text-muted">Review and approve pending checks</p>
    </div>

    <!-- Filters and Actions Bar -->
    <div class="actions-bar">
      <div class="selection-info">
        <span v-if="selectedChecks.length === 0">No checks selected</span>
        <span v-else>{{ selectedChecks.length }} check(s) selected</span>
      </div>
      <div class="action-buttons">
        <button 
          class="btn btn-success" 
          @click="bulkApprove"
          :disabled="selectedChecks.length === 0 || isProcessing"
        >
          <i class="bi bi-check-circle"></i>
          Approve Selected
        </button>
        <button 
          class="btn btn-primary" 
          @click="approveAndPrint"
          :disabled="selectedChecks.length === 0 || isProcessing"
        >
          <i class="bi bi-printer"></i>
          Approve & Print
        </button>
        <button 
          class="btn btn-outline-secondary" 
          @click="refreshQueue"
          :disabled="isLoading"
        >
          <i class="bi bi-arrow-clockwise"></i>
          Refresh
        </button>
      </div>
    </div>

    <!-- Loading State -->
    <div v-if="isLoading" class="loading-state">
      <div class="spinner-border text-primary" role="status">
        <span class="visually-hidden">Loading...</span>
      </div>
      <p>Loading pending checks...</p>
    </div>

    <!-- Error State -->
    <div v-if="error" class="alert alert-danger">
      <i class="bi bi-exclamation-triangle"></i>
      {{ error }}
    </div>

    <!-- Empty State -->
    <div v-if="!isLoading && pendingChecks.length === 0" class="empty-state">
      <i class="bi bi-check2-all"></i>
      <h3>All Clear!</h3>
      <p>No checks are waiting for approval.</p>
    </div>

    <!-- Checks Table -->
    <div v-if="!isLoading && pendingChecks.length > 0" class="checks-table-container">
      <table class="table table-hover">
        <thead>
          <tr>
            <th style="width: 50px">
              <input 
                type="checkbox" 
                class="form-check-input"
                @change="toggleSelectAll"
                :checked="allSelected"
              />
            </th>
            <th>Check #</th>
            <th>Date</th>
            <th>Payee</th>
            <th>Amount</th>
            <th>Account</th>
            <th>Submitted By</th>
            <th>Submitted</th>
            <th style="width: 200px">Actions</th>
          </tr>
        </thead>
        <tbody>
          <tr 
            v-for="check in pendingChecks" 
            :key="check.id"
            :class="{ 'table-warning': check.duplicate_count > 0, 'selected': selectedChecks.includes(check.id) }"
          >
            <td>
              <input 
                type="checkbox" 
                class="form-check-input"
                :value="check.id"
                v-model="selectedChecks"
              />
            </td>
            <td>
              <strong>{{ check.check_number }}</strong>
            </td>
            <td>{{ check.date }}</td>
            <td>
              {{ check.pay_to }}
              <span v-if="check.duplicate_count > 0" class="badge bg-warning text-dark ms-2" title="Possible duplicate">
                <i class="bi bi-exclamation-triangle"></i> Duplicate?
              </span>
            </td>
            <td class="amount">{{ formatCurrency(check.amount) }}</td>
            <td>
              <small class="text-muted">{{ check.account_name }}</small>
            </td>
            <td>
              <small>{{ check.created_by_email || 'Unknown' }}</small>
            </td>
            <td>
              <small>{{ formatTimeAgo(check.created_at) }}</small>
            </td>
            <td>
              <div class="btn-group btn-group-sm">
                <button 
                  class="btn btn-outline-primary" 
                  @click="previewCheck(check)"
                  title="Preview"
                >
                  <i class="bi bi-eye"></i>
                </button>
                <button 
                  class="btn btn-outline-secondary" 
                  @click="editCheck(check)"
                  title="Edit"
                >
                  <i class="bi bi-pencil"></i>
                </button>
                <button 
                  class="btn btn-outline-success" 
                  @click="approveSingle(check.id)"
                  :disabled="isProcessing"
                  title="Approve"
                >
                  <i class="bi bi-check"></i>
                </button>
                <button 
                  class="btn btn-outline-danger" 
                  @click="rejectCheck(check)"
                  title="Reject"
                >
                  <i class="bi bi-x"></i>
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Check Preview Modal -->
    <div 
      class="modal fade" 
      id="previewModal" 
      tabindex="-1" 
      ref="previewModal"
    >
      <div class="modal-dialog modal-xl">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Check Preview - #{{ previewingCheck?.check_number }}</h5>
            <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
          </div>
          <div class="modal-body">
            <div v-if="previewingCheck" class="check-preview-wrapper">
              <CheckPreview :check="previewingCheck" />
              
              <!-- Check Details -->
              <div class="check-details mt-4">
                <h6>Details</h6>
                <div class="row">
                  <div class="col-md-6">
                    <dl class="row">
                      <dt class="col-sm-4">Payee:</dt>
                      <dd class="col-sm-8">{{ previewingCheck.pay_to }}</dd>
                      
                      <dt class="col-sm-4">Amount:</dt>
                      <dd class="col-sm-8">{{ formatCurrency(previewingCheck.amount) }}</dd>
                      
                      <dt class="col-sm-4">Date:</dt>
                      <dd class="col-sm-8">{{ previewingCheck.date }}</dd>
                      
                      <dt class="col-sm-4">Memo:</dt>
                      <dd class="col-sm-8">{{ previewingCheck.memo || '(none)' }}</dd>
                    </dl>
                  </div>
                  <div class="col-md-6">
                    <dl class="row">
                      <dt class="col-sm-5">Account:</dt>
                      <dd class="col-sm-7">{{ previewingCheck.account_name }}</dd>
                      
                      <dt class="col-sm-5">Bank:</dt>
                      <dd class="col-sm-7">{{ previewingCheck.bank_name }}</dd>
                      
                      <dt class="col-sm-5">Category:</dt>
                      <dd class="col-sm-7">{{ previewingCheck.expense_category || '(none)' }}</dd>
                      
                      <dt class="col-sm-5">Business Unit:</dt>
                      <dd class="col-sm-7">{{ previewingCheck.business_unit || '(none)' }}</dd>
                    </dl>
                  </div>
                </div>
                
                <div v-if="previewingCheck.duplicate_count > 0" class="alert alert-warning mt-3">
                  <i class="bi bi-exclamation-triangle"></i>
                  <strong>Possible Duplicate:</strong> 
                  {{ previewingCheck.duplicate_count }} similar check(s) found in the last 7 days.
                </div>
              </div>
            </div>
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Close</button>
            <button 
              type="button" 
              class="btn btn-primary" 
              @click="editCheckFromPreview"
            >
              <i class="bi bi-pencil"></i> Edit
            </button>
            <button 
              type="button" 
              class="btn btn-danger" 
              @click="rejectCheckFromPreview"
            >
              <i class="bi bi-x-circle"></i> Reject
            </button>
            <button 
              type="button" 
              class="btn btn-success" 
              @click="approveCheckFromPreview"
              :disabled="isProcessing"
            >
              <i class="bi bi-check-circle"></i> Approve
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Edit Check Modal -->
    <div 
      class="modal fade" 
      id="editModal" 
      tabindex="-1" 
      ref="editModal"
    >
      <div class="modal-dialog modal-lg">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Edit Check - #{{ editingCheck?.check_number }}</h5>
            <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
          </div>
          <div class="modal-body">
            <form v-if="editingCheck" @submit.prevent="saveEdit">
              <div class="row">
                <div class="col-md-6 mb-3">
                  <label class="form-label">Payee *</label>
                  <input 
                    type="text" 
                    class="form-control" 
                    v-model="editingCheck.pay_to"
                    required
                  />
                </div>
                <div class="col-md-6 mb-3">
                  <label class="form-label">Amount *</label>
                  <input 
                    type="text" 
                    class="form-control" 
                    v-model="editingCheck.amount"
                    required
                  />
                </div>
              </div>
              
              <div class="row">
                <div class="col-md-6 mb-3">
                  <label class="form-label">Date *</label>
                  <input 
                    type="text" 
                    class="form-control" 
                    v-model="editingCheck.date"
                    required
                  />
                </div>
                <div class="col-md-6 mb-3">
                  <label class="form-label">Check Number *</label>
                  <input 
                    type="text" 
                    class="form-control" 
                    v-model="editingCheck.check_number"
                    required
                  />
                </div>
              </div>
              
              <div class="mb-3">
                <label class="form-label">Memo</label>
                <input 
                  type="text" 
                  class="form-control" 
                  v-model="editingCheck.memo"
                />
              </div>
              
              <div class="row">
                <div class="col-md-6 mb-3">
                  <label class="form-label">Expense Category</label>
                  <input 
                    type="text" 
                    class="form-control" 
                    v-model="editingCheck.expense_category"
                  />
                </div>
                <div class="col-md-6 mb-3">
                  <label class="form-label">Business Unit</label>
                  <input 
                    type="text" 
                    class="form-control" 
                    v-model="editingCheck.business_unit"
                  />
                </div>
              </div>
            </form>
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
            <button 
              type="button" 
              class="btn btn-primary" 
              @click="saveEdit"
              :disabled="isProcessing"
            >
              <i class="bi bi-save"></i> Save Changes
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Reject Check Modal -->
    <div 
      class="modal fade" 
      id="rejectModal" 
      tabindex="-1" 
      ref="rejectModal"
    >
      <div class="modal-dialog">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Reject Check</h5>
            <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
          </div>
          <div class="modal-body">
            <p>Are you sure you want to reject check #{{ rejectingCheck?.check_number }}?</p>
            <div class="mb-3">
              <label class="form-label">Reason for Rejection *</label>
              <textarea 
                class="form-control" 
                v-model="rejectionReason"
                rows="3"
                required
                placeholder="Please provide a reason..."
              ></textarea>
            </div>
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
            <button 
              type="button" 
              class="btn btn-danger" 
              @click="confirmReject"
              :disabled="!rejectionReason || isProcessing"
            >
              <i class="bi bi-x-circle"></i> Reject Check
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { Modal } from 'bootstrap'
import { supabase } from '../lib/supabase'
import CheckPreview from '../components/CheckPreview.vue'
import { log, error as logError } from '../utils/logger'

interface PendingCheck {
  id: string
  check_number: string
  date: string
  pay_to: string
  amount: string
  memo: string
  expense_category?: string
  business_unit?: string
  account_id: string
  account_name: string
  bank_name: string
  company_name: string
  created_by: string
  created_by_email: string
  created_at: string
  status: string
  duplicate_count: number
}

const pendingChecks = ref<PendingCheck[]>([])
const selectedChecks = ref<string[]>([])
const isLoading = ref(true)
const isProcessing = ref(false)
const error = ref<string | null>(null)

const previewingCheck = ref<PendingCheck | null>(null)
const editingCheck = ref<PendingCheck | null>(null)
const rejectingCheck = ref<PendingCheck | null>(null)
const rejectionReason = ref('')

let previewModalInstance: Modal | null = null
let editModalInstance: Modal | null = null
let rejectModalInstance: Modal | null = null

const previewModal = ref<HTMLElement | null>(null)
const editModal = ref<HTMLElement | null>(null)
const rejectModal = ref<HTMLElement | null>(null)

const allSelected = computed(() => {
  return pendingChecks.value.length > 0 && 
         selectedChecks.value.length === pendingChecks.value.length
})

onMounted(async () => {
  // Initialize Bootstrap modals
  if (previewModal.value) {
    previewModalInstance = new Modal(previewModal.value)
  }
  if (editModal.value) {
    editModalInstance = new Modal(editModal.value)
  }
  if (rejectModal.value) {
    rejectModalInstance = new Modal(rejectModal.value)
  }
  
  await loadPendingChecks()
})

async function loadPendingChecks() {
  try {
    isLoading.value = true
    error.value = null
    
    const { data, error: fetchError } = await supabase
      .from('approval_queue')
      .select('*')
      .order('created_at', { ascending: true })
    
    if (fetchError) throw fetchError
    
    pendingChecks.value = data || []
    log('Loaded pending checks:', data?.length)
  } catch (e) {
    logError('Failed to load pending checks:', e)
    error.value = 'Failed to load pending checks. Please try again.'
  } finally {
    isLoading.value = false
  }
}

async function refreshQueue() {
  await loadPendingChecks()
}

function toggleSelectAll(event: Event) {
  const target = event.target as HTMLInputElement
  if (target.checked) {
    selectedChecks.value = pendingChecks.value.map(c => c.id)
  } else {
    selectedChecks.value = []
  }
}

async function bulkApprove() {
  if (selectedChecks.value.length === 0) return
  
  try {
    isProcessing.value = true
    
    const { data, error: approveError } = await supabase.rpc('bulk_approve_checks', {
      p_check_ids: selectedChecks.value
    })
    
    if (approveError) throw approveError
    
    log('Bulk approval result:', data)
    
    const failures = data?.filter((r: any) => !r.success) || []
    if (failures.length > 0) {
      alert(`${failures.length} check(s) failed to approve:\n${failures.map((f: any) => f.error).join('\n')}`)
    }
    
    const successCount = data?.filter((r: any) => r.success).length || 0
    if (successCount > 0) {
      alert(`Successfully approved ${successCount} check(s)`)
    }
    
    selectedChecks.value = []
    await loadPendingChecks()
  } catch (e) {
    logError('Bulk approve failed:', e)
    alert('Failed to approve checks: ' + (e as Error).message)
  } finally {
    isProcessing.value = false
  }
}

async function approveAndPrint() {
  if (selectedChecks.value.length === 0) return
  
  await bulkApprove()
  
  // Navigate to print view with approved checks
  // This would require updating the CheckPrinter component to support batch printing
  alert('Checks approved. Navigate to Print view to print them.')
}

async function approveSingle(checkId: string) {
  try {
    isProcessing.value = true
    
    const { data, error: approveError } = await supabase.rpc('bulk_approve_checks', {
      p_check_ids: [checkId]
    })
    
    if (approveError) throw approveError
    
    const result = data?.[0]
    if (result?.success) {
      alert('Check approved successfully')
      await loadPendingChecks()
    } else {
      alert('Failed to approve check: ' + result?.error)
    }
  } catch (e) {
    logError('Approve failed:', e)
    alert('Failed to approve check: ' + (e as Error).message)
  } finally {
    isProcessing.value = false
  }
}

function previewCheck(check: PendingCheck) {
  previewingCheck.value = { ...check }
  previewModalInstance?.show()
}

function editCheck(check: PendingCheck) {
  editingCheck.value = { ...check }
  editModalInstance?.show()
}

async function saveEdit() {
  if (!editingCheck.value) return
  
  try {
    isProcessing.value = true
    
    const { error: updateError } = await supabase
      .from('checks')
      .update({
        pay_to: editingCheck.value.pay_to,
        amount: editingCheck.value.amount,
        date: editingCheck.value.date,
        check_number: editingCheck.value.check_number,
        memo: editingCheck.value.memo,
        expense_category: editingCheck.value.expense_category,
        business_unit: editingCheck.value.business_unit,
      })
      .eq('id', editingCheck.value.id)
    
    if (updateError) throw updateError
    
    alert('Check updated successfully')
    editModalInstance?.hide()
    await loadPendingChecks()
  } catch (e) {
    logError('Update failed:', e)
    alert('Failed to update check: ' + (e as Error).message)
  } finally {
    isProcessing.value = false
  }
}

function rejectCheck(check: PendingCheck) {
  rejectingCheck.value = check
  rejectionReason.value = ''
  rejectModalInstance?.show()
}

async function confirmReject() {
  if (!rejectingCheck.value || !rejectionReason.value) return
  
  try {
    isProcessing.value = true
    
    const { error: rejectError } = await supabase
      .from('checks')
      .update({
        status: 'rejected',
        rejected_by: (await supabase.auth.getUser()).data.user?.id,
        rejected_at: new Date().toISOString(),
        rejection_reason: rejectionReason.value,
      })
      .eq('id', rejectingCheck.value.id)
    
    if (rejectError) throw rejectError
    
    alert('Check rejected')
    rejectModalInstance?.hide()
    await loadPendingChecks()
  } catch (e) {
    logError('Reject failed:', e)
    alert('Failed to reject check: ' + (e as Error).message)
  } finally {
    isProcessing.value = false
  }
}

function approveCheckFromPreview() {
  if (previewingCheck.value) {
    previewModalInstance?.hide()
    approveSingle(previewingCheck.value.id)
  }
}

function editCheckFromPreview() {
  if (previewingCheck.value) {
    previewModalInstance?.hide()
    editCheck(previewingCheck.value)
  }
}

function rejectCheckFromPreview() {
  if (previewingCheck.value) {
    previewModalInstance?.hide()
    rejectCheck(previewingCheck.value)
  }
}

function formatCurrency(amount: string): string {
  try {
    const num = parseFloat(amount.replace(/[$,]/g, ''))
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD'
    }).format(num)
  } catch {
    return amount
  }
}

function formatTimeAgo(timestamp: string): string {
  const date = new Date(timestamp)
  const now = new Date()
  const diff = now.getTime() - date.getTime()
  
  const minutes = Math.floor(diff / 60000)
  const hours = Math.floor(diff / 3600000)
  const days = Math.floor(diff / 86400000)
  
  if (minutes < 60) return `${minutes}m ago`
  if (hours < 24) return `${hours}h ago`
  return `${days}d ago`
}
</script>

<style scoped>
.approval-queue-container {
  max-width: 1400px;
  margin: 0 auto;
  padding: 20px;
}

.page-header {
  margin-bottom: 30px;
}

.page-header h1 {
  font-size: 2rem;
  font-weight: 600;
  color: #333;
}

.page-header i {
  margin-right: 10px;
  color: #0d6efd;
}

.actions-bar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
  padding: 15px;
  background: #f8f9fa;
  border-radius: 8px;
}

.selection-info {
  font-weight: 500;
  color: #666;
}

.action-buttons {
  display: flex;
  gap: 10px;
}

.loading-state {
  text-align: center;
  padding: 60px 20px;
}

.empty-state {
  text-align: center;
  padding: 60px 20px;
  color: #6c757d;
}

.empty-state i {
  font-size: 4rem;
  margin-bottom: 20px;
  color: #28a745;
}

.empty-state h3 {
  font-size: 1.5rem;
  margin-bottom: 10px;
}

.checks-table-container {
  background: white;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
  overflow: hidden;
}

.table {
  margin-bottom: 0;
}

.table thead {
  background: #f8f9fa;
  border-bottom: 2px solid #dee2e6;
}

.table tbody tr {
  transition: background-color 0.2s;
}

.table tbody tr:hover {
  background-color: #f8f9fa;
}

.table tbody tr.selected {
  background-color: #e7f3ff;
}

.table tbody tr.table-warning {
  background-color: #fff3cd;
}

.amount {
  font-weight: 600;
  color: #198754;
}

.check-preview-wrapper {
  padding: 20px;
}

.check-details {
  padding: 20px;
  background: #f8f9fa;
  border-radius: 8px;
}

.check-details h6 {
  font-weight: 600;
  margin-bottom: 15px;
  color: #333;
}

.check-details dl {
  margin-bottom: 0;
}

.check-details dt {
  font-weight: 600;
  color: #666;
}

.check-details dd {
  color: #333;
}
</style>
