/**
 * Input validation utilities for financial data
 */

/**
 * Validate routing number (9 digits, ABA routing number with checksum)
 */
export function validateRoutingNumber(routingNumber: string): { valid: boolean; error?: string } {
  // Remove any spaces or dashes
  const cleaned = routingNumber.replace(/[\s-]/g, '')
  
  // Must be exactly 9 digits
  if (!/^\d{9}$/.test(cleaned)) {
    return { valid: false, error: 'Routing number must be exactly 9 digits' }
  }
  
  // ABA routing number checksum validation
  // Formula: 3(d1 + d4 + d7) + 7(d2 + d5 + d8) + (d3 + d6 + d9) must be divisible by 10
  const digits = cleaned.split('').map(Number)
  const checksum = 
    3 * (digits[0] + digits[3] + digits[6]) +
    7 * (digits[1] + digits[4] + digits[7]) +
    (digits[2] + digits[5] + digits[8])
  
  if (checksum % 10 !== 0) {
    return { valid: false, error: 'Invalid routing number checksum' }
  }
  
  return { valid: true }
}

/**
 * Validate account number (typically 4-17 digits, varies by bank)
 */
export function validateAccountNumber(accountNumber: string): { valid: boolean; error?: string } {
  // Remove any spaces or dashes
  const cleaned = accountNumber.replace(/[\s-]/g, '')
  
  // Must be between 4 and 17 digits (US standard)
  if (!/^\d{4,17}$/.test(cleaned)) {
    return { valid: false, error: 'Account number must be 4-17 digits' }
  }
  
  return { valid: true }
}

/**
 * Validate check amount (positive number, reasonable range)
 */
export function validateCheckAmount(amount: string): { valid: boolean; error?: string } {
  const cleaned = amount.replace(/[$,\s]/g, '')
  const num = parseFloat(cleaned)
  
  if (isNaN(num)) {
    return { valid: false, error: 'Amount must be a valid number' }
  }
  
  if (num <= 0) {
    return { valid: false, error: 'Amount must be greater than zero' }
  }
  
  if (num > 999999.99) {
    return { valid: false, error: 'Amount exceeds maximum limit ($999,999.99)' }
  }
  
  // Check for at most 2 decimal places
  if (!/^\d+(\.\d{1,2})?$/.test(cleaned)) {
    return { valid: false, error: 'Amount can have at most 2 decimal places' }
  }
  
  return { valid: true }
}

/**
 * Validate check number (alphanumeric, reasonable length)
 */
export function validateCheckNumber(checkNumber: string): { valid: boolean; error?: string } {
  if (!checkNumber || checkNumber.trim().length === 0) {
    return { valid: false, error: 'Check number is required' }
  }
  
  if (checkNumber.length > 10) {
    return { valid: false, error: 'Check number too long (max 10 characters)' }
  }
  
  // Allow digits and basic punctuation
  if (!/^[\d\-\/]+$/.test(checkNumber)) {
    return { valid: false, error: 'Check number can only contain digits, hyphens, and slashes' }
  }
  
  return { valid: true }
}

/**
 * Validate email address
 */
export function validateEmail(email: string): { valid: boolean; error?: string } {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
  
  if (!emailRegex.test(email)) {
    return { valid: false, error: 'Invalid email address' }
  }
  
  return { valid: true }
}

/**
 * Validate payee name (prevent injection attacks)
 */
export function validatePayeeName(payee: string): { valid: boolean; error?: string } {
  if (!payee || payee.trim().length === 0) {
    return { valid: false, error: 'Payee name is required' }
  }
  
  if (payee.length > 100) {
    return { valid: false, error: 'Payee name too long (max 100 characters)' }
  }
  
  // Block common injection patterns
  const dangerousPatterns = [
    /<script/i,
    /javascript:/i,
    /on\w+\s*=/i,  // event handlers
    /<iframe/i,
    /\0/,  // null byte
  ]
  
  for (const pattern of dangerousPatterns) {
    if (pattern.test(payee)) {
      return { valid: false, error: 'Payee name contains invalid characters' }
    }
  }
  
  return { valid: true }
}

/**
 * Sanitize text input (remove HTML, scripts)
 */
export function sanitizeText(text: string): string {
  if (!text) return ''
  
  return text
    .replace(/<script[^>]*>.*?<\/script>/gi, '')
    .replace(/<[^>]+>/g, '')  // Remove HTML tags
    .replace(/javascript:/gi, '')
    .replace(/on\w+\s*=/gi, '')  // Remove event handlers
    .trim()
}

/**
 * Mask sensitive data for display (show only last 4 digits)
 */
export function maskAccountNumber(accountNumber: string): string {
  if (!accountNumber || accountNumber.length < 4) return '****'
  return '*'.repeat(accountNumber.length - 4) + accountNumber.slice(-4)
}

/**
 * Mask routing number (show only last 4 digits)
 */
export function maskRoutingNumber(routingNumber: string): string {
  if (!routingNumber || routingNumber.length < 4) return '****'
  return '*****' + routingNumber.slice(-4)
}
