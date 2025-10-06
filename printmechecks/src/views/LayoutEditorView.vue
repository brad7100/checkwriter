<template>
  <div class="layout-editor-page">
    <!-- Header -->
    <div class="editor-header">
      <div class="container-fluid">
        <div class="d-flex justify-content-between align-items-center py-3">
          <div>
            <button class="btn btn-outline-secondary me-3" @click="goBack">
              <i class="bi bi-arrow-left"></i> Back to Layouts
            </button>
            <input 
              v-if="currentLayout" 
              type="text" 
              class="form-control d-inline-block" 
              style="width: 300px;"
              v-model="currentLayout.name"
              placeholder="Layout Name"
            />
          </div>
          <div>
            <button class="btn btn-success me-2" @click="saveLayout">
              <i class="bi bi-save"></i> Save Layout
            </button>
            <button class="btn btn-outline-secondary" @click="togglePreview">
              <i class="bi bi-eye"></i> {{ showPreview ? 'Hide' : 'Show' }} Preview Data
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Main Editor Area -->
    <div class="editor-content">
      <div class="container-fluid">
        <div class="row">
          <!-- Instructions -->
          <div class="col-12 mb-3">
            <div class="alert alert-info mb-0">
              <strong><i class="bi bi-lightbulb"></i> Quick Tips:</strong>
              <span class="ms-2">
                • <strong>Click</strong> any field to select it (blue border)
                • <strong>Drag</strong> with mouse to move (auto-snaps to 10px grid)
                • <strong>Arrow keys ↑ ↓ ← →</strong> move selected field by 10px
                • <strong>Shift + Arrow keys</strong> for 1px fine adjustment
                • <strong>Delete or Backspace</strong> removes selected element
                • Grid spacing = 10px for perfect alignment
                <span v-if="selectedAccount?.backgroundColor" class="ms-3">
                  • <strong style="color: #28a745;">✓</strong> Account background color is shown
                </span>
              </span>
            </div>
          </div>

          <!-- Check Preview -->
          <div class="col-12 mb-4">
            <div class="check-preview-container">
              <div 
                class="check-canvas" 
                ref="checkCanvas"
                :style="canvasStyle"
                @click="deselectField"
              >
                <!-- Background grid -->
                <div class="grid-background"></div>
                
                <!-- MICR Line (Fixed) -->
                <div class="micr-line" :style="micrStyle">
                  <span v-if="showPreview && selectedAccount">
                    a{{ selectedAccount.routingNumber }}a {{ selectedAccount.accountNumber }}c {{ previewData.checkNumber }}
                  </span>
                  <span v-else class="text-muted">MICR Line (Fixed Position)</span>
                </div>

                <!-- No fixed check number; add via Fields tab as a data-bound field -->

                <!-- Rendered Fields -->
                <div
                  v-for="field in currentLayout?.fields || []"
                  :key="field.id"
                  class="layout-field"
                  :class="{ 'selected': selectedFieldId === field.id }"
                  :style="getFieldStyle(field)"
                  @click.stop="selectField(field.id)"
                  @mousedown="startDrag(field.id, $event)"
                >
                  {{ getFieldContent(field) }}
                </div>

                <!-- Rendered Drawing Elements (Lines/Boxes) -->
                <div
                  v-for="element in currentLayout?.drawingElements || []"
                  :key="element.id"
                  class="drawing-element"
                  :class="{ 'selected': selectedFieldId === element.id }"
                  :style="getElementStyle(element)"
                  @click.stop="selectField(element.id)"
                  @mousedown="startDrag(element.id, $event)"
                >
                </div>

                <!-- No Account Selected Overlay -->
                <div v-if="!selectedAccount && showPreview" class="no-account-overlay">
                  <div class="overlay-message">
                    <i class="bi bi-exclamation-circle display-1"></i>
                    <h3>No Account Selected</h3>
                    <p>Please select a company and account to preview</p>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- Controls Panel -->
          <div class="col-12">
            <div class="controls-panel">
              <ul class="nav nav-tabs" role="tablist">
                <li class="nav-item">
                  <a class="nav-link" :class="{ active: activeTab === 'fields' }" @click="activeTab = 'fields'">
                    <i class="bi bi-input-cursor-text"></i> Fields
                  </a>
                </li>
                <li class="nav-item">
                  <a class="nav-link" :class="{ active: activeTab === 'drawing' }" @click="activeTab = 'drawing'">
                    <i class="bi bi-pencil"></i> Lines & Boxes
                  </a>
                </li>
                <li class="nav-item" v-if="selectedField">
                  <a class="nav-link" :class="{ active: activeTab === 'properties' }" @click="activeTab = 'properties'">
                    <i class="bi bi-sliders"></i> Properties
                  </a>
                </li>
              </ul>

              <div class="tab-content p-3">
                <!-- Fields Tab -->
                <div v-if="activeTab === 'fields'" class="tab-pane-content">
                  <h5>Available Fields</h5>
                  <p class="text-muted small">Click to add a field to the check</p>
                  <div class="row g-2">
                    <div class="col-md-3" v-for="fieldType in availableFields" :key="fieldType.binding">
                      <button class="btn btn-outline-primary w-100" @click="addField(fieldType.binding, fieldType.label)">
                        <i class="bi bi-plus-circle me-1"></i> {{ fieldType.label }}
                      </button>
                    </div>
                    <div class="col-md-3">
                      <button class="btn btn-outline-secondary w-100" @click="addTextField">
                        <i class="bi bi-fonts me-1"></i> Text Box
                      </button>
                    </div>
                  </div>
                </div>

                <!-- Drawing Tab -->
                <div v-if="activeTab === 'drawing'" class="tab-pane-content">
                  <h5>Drawing Tools</h5>
                  <p class="text-muted small">Add lines and boxes to your check</p>
                  <div class="row g-2">
                    <div class="col-md-3">
                      <button class="btn btn-outline-primary w-100" @click="addLine">
                        <i class="bi bi-dash-lg me-1"></i> Add Line
                      </button>
                    </div>
                    <div class="col-md-3">
                      <button class="btn btn-outline-primary w-100" @click="addBox">
                        <i class="bi bi-square me-1"></i> Add Box
                      </button>
                    </div>
                  </div>
                </div>

                <!-- Properties Tab -->
                <div v-if="activeTab === 'properties' && selectedField" class="tab-pane-content">
                  <h5>Element Properties</h5>
                  
                  <!-- Field Properties -->
                  <div v-if="selectedField.type === 'text' || selectedField.type === 'data'">
                    <div class="row g-3">
                      <div class="col-md-3">
                        <label class="form-label">X Position</label>
                        <input type="number" class="form-control" v-model.number="selectedField.x" step="10">
                      </div>
                      <div class="col-md-3">
                        <label class="form-label">Y Position</label>
                        <input type="number" class="form-control" v-model.number="selectedField.y" step="10">
                      </div>
                      <div class="col-md-3">
                        <label class="form-label">Width</label>
                        <input type="number" class="form-control" v-model.number="selectedField.width" step="10">
                      </div>
                      <div class="col-md-3">
                        <label class="form-label">Height</label>
                        <input type="number" class="form-control" v-model.number="selectedField.height" step="10">
                      </div>
                      <div class="col-md-3">
                        <label class="form-label">Font Family</label>
                        <select class="form-select" v-model="selectedField.fontFamily">
                          <option value="Arial">Arial</option>
                          <option value="Times New Roman">Times New Roman</option>
                          <option value="Courier New">Courier New</option>
                          <option value="Georgia">Georgia</option>
                          <option value="Verdana">Verdana</option>
                          <option value="Caveat, cursive">Caveat (Handwriting)</option>
                        </select>
                      </div>
                      <div class="col-md-2">
                        <label class="form-label">Font Size</label>
                        <input type="number" class="form-control" v-model.number="selectedField.fontSize" min="8" max="72">
                      </div>
                      <div class="col-md-2">
                        <label class="form-label">Alignment</label>
                        <select class="form-select" v-model="selectedField.textAlign">
                          <option value="left">Left</option>
                          <option value="center">Center</option>
                          <option value="right">Right</option>
                        </select>
                      </div>
                      <div class="col-md-2">
                        <label class="form-label">Color</label>
                        <input type="color" class="form-control form-control-color" v-model="selectedField.color">
                      </div>
                      <div class="col-md-3">
                        <label class="form-label d-block">&nbsp;</label>
                        <div class="form-check form-check-inline">
                          <input class="form-check-input" type="checkbox" v-model="selectedField.fontWeight">
                          <label class="form-check-label">Bold</label>
                        </div>
                        <div class="form-check form-check-inline">
                          <input class="form-check-input" type="checkbox" v-model="selectedField.fontStyle">
                          <label class="form-check-label">Italic</label>
                        </div>
                      </div>
                      <div class="col-md-12" v-if="selectedField.type === 'text'">
                        <label class="form-label">Text Content</label>
                        <input type="text" class="form-control" v-model="selectedField.text">
                      </div>
                      <div class="col-md-12">
                        <button class="btn btn-danger btn-sm" @click="deleteField(selectedField.id)">
                          <i class="bi bi-trash"></i> Delete Field
                        </button>
                      </div>
                    </div>
                  </div>

                  <!-- Drawing Element Properties -->
                  <div v-if="selectedField.type === 'line' || selectedField.type === 'box'">
                    <div class="row g-3">
                      <div class="col-md-3">
                        <label class="form-label">X Position</label>
                        <input type="number" class="form-control" v-model.number="selectedField.x" step="10">
                      </div>
                      <div class="col-md-3">
                        <label class="form-label">Y Position</label>
                        <input type="number" class="form-control" v-model.number="selectedField.y" step="10">
                      </div>
                      <div class="col-md-3">
                        <label class="form-label">Width</label>
                        <input type="number" class="form-control" v-model.number="selectedField.width" step="10">
                      </div>
                      <div class="col-md-3">
                        <label class="form-label">Height</label>
                        <input type="number" class="form-control" v-model.number="selectedField.height" step="10">
                      </div>
                      <div class="col-md-3">
                        <label class="form-label">Stroke Width</label>
                        <input type="number" class="form-control" v-model.number="selectedField.strokeWidth" min="1" max="10">
                      </div>
                      <div class="col-md-3">
                        <label class="form-label">Stroke Color</label>
                        <input type="color" class="form-control form-control-color" v-model="selectedField.strokeColor">
                      </div>
                      <div class="col-md-3" v-if="selectedField.type === 'box'">
                        <label class="form-label">Fill Color</label>
                        <input type="color" class="form-control form-control-color" v-model="selectedField.fillColor">
                      </div>
                      <div class="col-md-3">
                        <label class="form-label">Rotation (deg)</label>
                        <input type="number" class="form-control" v-model.number="selectedField.rotation" step="1">
                      </div>
                      <div class="col-md-12">
                        <button class="btn btn-danger btn-sm" @click="deleteField(selectedField.id)">
                          <i class="bi bi-trash"></i> Delete Element
                        </button>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAppStore, type LayoutField, type DrawingElement } from '../stores/app'

const route = useRoute()
const router = useRouter()
const store = useAppStore()

const layoutId = computed(() => route.params.id as string)
const currentLayout = computed(() => store.customLayouts.find(l => l.id === layoutId.value))
const selectedAccount = computed(() => store.selectedAccount)
const selectedCompany = computed(() => store.selectedCompany)

const selectedFieldId = ref<string | null>(null)
const selectedField = computed(() => {
  if (!selectedFieldId.value || !currentLayout.value) return null
  const field = currentLayout.value.fields.find(f => f.id === selectedFieldId.value)
  if (field) return field
  return currentLayout.value.drawingElements?.find(e => e.id === selectedFieldId.value)
})

const activeTab = ref('fields')
const showPreview = ref(false)
const checkCanvas = ref<HTMLElement | null>(null)
const isDragging = ref(false)
const dragStart = ref({ x: 0, y: 0 })

const canvasStyle = computed(() => {
  const bgImageUrl = new URL('../assets/checkbg.png', import.meta.url).href
  
  // Get account background color if available
  const backgroundColor = selectedAccount.value?.backgroundColor || ''
  
  // Create layered background with color tint
  let backgroundStyle = `url(${bgImageUrl}) no-repeat`
  if (backgroundColor) {
    backgroundStyle = `linear-gradient(${backgroundColor}33, ${backgroundColor}33), ${backgroundStyle}`
  }
  
  return {
    width: '1200px',
    height: '415px',
    position: 'relative',
    border: '1px solid #ccc',
    background: backgroundStyle,
    backgroundSize: '1200px 410px',
    margin: '0 auto',
    overflow: 'hidden'
  }
})

const micrStyle = computed(() => ({
  position: 'absolute',
  top: '420px',
  left: '80px',
  fontFamily: 'MICR, monospace',
  fontSize: '37px',
  pointerEvents: 'none'
}))

// Removed fixed check number style; use a normal field instead

const previewData = ref({
  checkNumber: '1001',
  date: new Date().toLocaleDateString(),
  payTo: 'Sample Payee',
  amount: '1,234.56',
  amountWords: 'One Thousand Two Hundred Thirty Four and 56/100',
  memo: 'Sample Memo',
  signature: 'John Doe',
  mailToCity: 'Los Angeles',
  mailToState: 'CA',
  mailToZip: '90210'
})

const availableFields = [
  { binding: 'checkNumber', label: 'Check Number' },
  { binding: 'accountName', label: 'Account Name' },
  { binding: 'accountHolderName', label: 'Company Name' },
  { binding: 'accountHolderAddress', label: 'Company Address' },
  { binding: 'accountHolderCityStateZip', label: 'Company City, ST ZIP' },
  { binding: 'accountHolderCity', label: 'Company City' },
  { binding: 'accountHolderState', label: 'Company State' },
  { binding: 'accountHolderZip', label: 'Company ZIP' },
  { binding: 'date', label: 'Date' },
  { binding: 'payTo', label: 'Pay To' },
  { binding: 'amount', label: 'Amount' },
  { binding: 'amountWords', label: 'Amount in Words' },
  { binding: 'bankName', label: 'Bank Name' },
  { binding: 'bankCity', label: 'Bank City' },
  { binding: 'memo', label: 'Memo' },
  { binding: 'signature', label: 'Signature' },
  { binding: 'mailToName', label: 'Payee Name' },
  { binding: 'mailToAddress', label: 'Payee Address' },
  { binding: 'mailToCityStateZip', label: 'Payee City, ST ZIP' },
  { binding: 'mailToCity', label: 'Payee City' },
  { binding: 'mailToState', label: 'Payee State' },
  { binding: 'mailToZip', label: 'Payee ZIP' }
]

const togglePreview = () => {
  showPreview.value = !showPreview.value
}

const goBack = () => {
  router.push('/layouts')
}

const saveLayout = async () => {
  if (currentLayout.value) {
    await store.updateCustomLayout(layoutId.value, currentLayout.value)
    alert('Layout saved successfully!')
  }
}

const selectField = (fieldId: string) => {
  selectedFieldId.value = fieldId
  activeTab.value = 'properties'
}

const deselectField = () => {
  selectedFieldId.value = null
  if (activeTab.value === 'properties') {
    activeTab.value = 'fields'
  }
}

const addField = (binding: string, label: string) => {
  if (!currentLayout.value) return
  
  const newField: LayoutField = {
    id: `field_${Date.now()}`,
    type: 'data',
    dataBinding: binding,
    x: 100,
    y: 100,
    width: 200,
    height: 30,
    fontFamily: 'Arial',
    fontSize: 16,
    fontWeight: false,
    fontStyle: false,
    color: '#000000',
    textAlign: 'left'
  }
  
  currentLayout.value.fields.push(newField)
  selectedFieldId.value = newField.id
  activeTab.value = 'properties'
}

const addTextField = () => {
  if (!currentLayout.value) return
  
  const newField: LayoutField = {
    id: `text_${Date.now()}`,
    type: 'text',
    text: 'Text Label',
    x: 100,
    y: 100,
    width: 200,
    height: 30,
    fontFamily: 'Arial',
    fontSize: 16,
    fontWeight: false,
    fontStyle: false,
    color: '#000000',
    textAlign: 'left'
  }
  
  currentLayout.value.fields.push(newField)
  selectedFieldId.value = newField.id
  activeTab.value = 'properties'
}

const addLine = () => {
  if (!currentLayout.value) return
  
  const newLine: DrawingElement = {
    id: `line_${Date.now()}`,
    type: 'line',
    x: 100,
    y: 200,
    width: 200,
    height: 1,
    strokeWidth: 1,
    strokeColor: '#000000',
    rotation: 0
  }
  
  if (!currentLayout.value.drawingElements) {
    currentLayout.value.drawingElements = []
  }
  currentLayout.value.drawingElements.push(newLine)
  selectedFieldId.value = newLine.id
  activeTab.value = 'properties'
}

const addBox = () => {
  if (!currentLayout.value) return
  
  const newBox: DrawingElement = {
    id: `box_${Date.now()}`,
    type: 'box',
    x: 100,
    y: 200,
    width: 150,
    height: 100,
    strokeWidth: 1,
    strokeColor: '#000000',
    fillColor: 'transparent',
    rotation: 0
  }
  
  if (!currentLayout.value.drawingElements) {
    currentLayout.value.drawingElements = []
  }
  currentLayout.value.drawingElements.push(newBox)
  selectedFieldId.value = newBox.id
  activeTab.value = 'properties'
}

const deleteField = (fieldId: string) => {
  if (!currentLayout.value) return
  if (!confirm('Delete this element?')) return
  
  currentLayout.value.fields = currentLayout.value.fields.filter(f => f.id !== fieldId)
  if (currentLayout.value.drawingElements) {
    currentLayout.value.drawingElements = currentLayout.value.drawingElements.filter(e => e.id !== fieldId)
  }
  selectedFieldId.value = null
}

const getFieldStyle = (field: LayoutField) => {
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
    cursor: 'move',
    userSelect: 'none',
    border: '1px dashed transparent',
    padding: '2px',
    overflow: 'hidden',
    whiteSpace: 'nowrap',
    textOverflow: 'ellipsis'
  }
}

const getElementStyle = (element: DrawingElement) => {
  const baseStyle: any = {
    position: 'absolute',
    left: `${element.x}px`,
    top: `${element.y}px`,
    width: `${element.width}px`,
    height: `${element.height}px`,
    cursor: 'move',
    pointerEvents: 'auto',
    transform: element.rotation ? `rotate(${element.rotation}deg)` : 'none'
  }
  
  if (element.type === 'line') {
    baseStyle.borderTop = `${element.strokeWidth}px solid ${element.strokeColor}`
    baseStyle.height = '0px'
  } else if (element.type === 'box') {
    baseStyle.border = `${element.strokeWidth}px solid ${element.strokeColor}`
    baseStyle.backgroundColor = element.fillColor || 'transparent'
  }
  
  return baseStyle
}

const getFieldContent = (field: LayoutField) => {
  if (field.type === 'text') {
    return field.text || 'Text'
  }
  
  if (!showPreview.value) {
    return `{${field.dataBinding}}`
  }
  
  // Return preview data
  const binding = field.dataBinding
  
  // Combined city, state, zip fields
  if (binding === 'accountHolderCityStateZip' && selectedCompany.value) {
    return `${selectedCompany.value.city}, ${selectedCompany.value.state} ${selectedCompany.value.zip}`
  }
  if (binding === 'mailToCityStateZip') {
    return `${previewData.value.mailToCity || ''}, ${previewData.value.mailToState || ''} ${previewData.value.mailToZip || ''}`
  }
  
  // Individual fields
  if (binding === 'accountName' && selectedAccount.value) return selectedAccount.value.name
  if (binding === 'accountHolderName' && selectedCompany.value) return selectedCompany.value.name
  if (binding === 'accountHolderAddress' && selectedCompany.value) return selectedCompany.value.address
  if (binding === 'accountHolderCity' && selectedCompany.value) return selectedCompany.value.city
  if (binding === 'accountHolderState' && selectedCompany.value) return selectedCompany.value.state
  if (binding === 'accountHolderZip' && selectedCompany.value) return selectedCompany.value.zip
  if (binding === 'bankName' && selectedAccount.value) return selectedAccount.value.bankName
  if (binding === 'bankCity' && selectedAccount.value) return selectedAccount.value.bankCity || ''
  if (binding === 'signature' && selectedAccount.value) return selectedAccount.value.signature
  
  return (previewData.value as any)[binding] || `{${binding}}`
}

const startDrag = (fieldId: string, event: MouseEvent) => {
  event.preventDefault()
  selectedFieldId.value = fieldId
  isDragging.value = true
  dragStart.value = { x: event.clientX, y: event.clientY }
  
  const onMouseMove = (e: MouseEvent) => {
    if (!isDragging.value || !selectedField.value) return
    
    const deltaX = e.clientX - dragStart.value.x
    const deltaY = e.clientY - dragStart.value.y
    
    // Snap to 10px grid
    const newX = Math.round((selectedField.value.x + deltaX) / 10) * 10
    const newY = Math.round((selectedField.value.y + deltaY) / 10) * 10
    
    selectedField.value.x = Math.max(0, Math.min(1200 - selectedField.value.width, newX))
    selectedField.value.y = Math.max(0, Math.min(415 - selectedField.value.height, newY))
    
    dragStart.value = { x: e.clientX, y: e.clientY }
  }
  
  const onMouseUp = () => {
    isDragging.value = false
    document.removeEventListener('mousemove', onMouseMove)
    document.removeEventListener('mouseup', onMouseUp)
  }
  
  document.addEventListener('mousemove', onMouseMove)
  document.addEventListener('mouseup', onMouseUp)
}

const handleKeyDown = (event: KeyboardEvent) => {
  // Only handle if a field is selected and not typing in an input
  if (!selectedField.value) return
  if ((event.target as HTMLElement).tagName === 'INPUT' || (event.target as HTMLElement).tagName === 'TEXTAREA') return
  
  const step = event.shiftKey ? 1 : 10
  
  switch (event.key) {
    case 'ArrowLeft':
      event.preventDefault()
      selectedField.value.x = Math.max(0, selectedField.value.x - step)
      break
    case 'ArrowRight':
      event.preventDefault()
      selectedField.value.x = Math.min(1200 - selectedField.value.width, selectedField.value.x + step)
      break
    case 'ArrowUp':
      event.preventDefault()
      selectedField.value.y = Math.max(0, selectedField.value.y - step)
      break
    case 'ArrowDown':
      event.preventDefault()
      selectedField.value.y = Math.min(415 - selectedField.value.height, selectedField.value.y + step)
      break
    case 'Delete':
    case 'Backspace':
      event.preventDefault()
      deleteField(selectedField.value.id)
      break
  }
}

onMounted(() => {
  if (!currentLayout.value) {
    alert('Layout not found')
    goBack()
  }
  
  // Add global keyboard listener
  document.addEventListener('keydown', handleKeyDown)
})

onUnmounted(() => {
  // Remove global keyboard listener
  document.removeEventListener('keydown', handleKeyDown)
})
</script>

<style scoped>
.layout-editor-page {
  min-height: 100vh;
  background-color: #f5f5f5;
}

.editor-header {
  background-color: white;
  border-bottom: 1px solid #dee2e6;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.editor-content {
  padding: 20px 0;
}

.check-preview-container {
  background-color: white;
  padding: 20px;
  border-radius: 8px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
  display: flex;
  justify-content: center;
}

.check-canvas {
  box-sizing: border-box;
}

.check-canvas::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-image: 
    linear-gradient(90deg, rgba(100,100,100,0.15) 1px, transparent 1px),
    linear-gradient(rgba(100,100,100,0.15) 1px, transparent 1px);
  background-size: 10px 10px;
  pointer-events: none;
  z-index: 1;
}

.grid-background {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  pointer-events: none;
}

.layout-field {
  transition: border-color 0.2s;
  position: relative;
  z-index: 10;
}

.layout-field:hover,
.drawing-element:hover {
  border-color: #0d6efd !important;
  border-style: dashed !important;
}

.layout-field.selected,
.drawing-element.selected {
  border: 2px solid #0d6efd !important;
  background-color: rgba(13, 110, 253, 0.05);
  outline: none;
}

.layout-field:focus,
.drawing-element:focus {
  outline: 2px solid #0d6efd;
  outline-offset: 2px;
}

.drawing-element {
  box-sizing: border-box;
  position: relative;
  z-index: 10;
}

.no-account-overlay {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(255, 255, 255, 0.9);
  display: flex;
  align-items: center;
  justify-content: center;
  pointer-events: none;
}

.overlay-message {
  text-align: center;
  color: #6c757d;
}

.controls-panel {
  background-color: white;
  border-radius: 8px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
  overflow: hidden;
}

.nav-tabs {
  border-bottom: 1px solid #dee2e6;
  margin-bottom: 0;
}

.nav-tabs .nav-link {
  cursor: pointer;
  border: none;
  border-bottom: 2px solid transparent;
}

.nav-tabs .nav-link:hover {
  border-bottom-color: #dee2e6;
}

.nav-tabs .nav-link.active {
  border-bottom-color: #0d6efd;
  color: #0d6efd;
  font-weight: 500;
}

.tab-pane-content {
  min-height: 200px;
}

.micr-line,
.check-number-fixed {
  pointer-events: none;
  user-select: none;
  position: relative;
  z-index: 5;
}
</style>
