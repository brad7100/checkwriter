/**
 * Secure logging utility that sanitizes sensitive data in production
 */

const isProduction = import.meta.env.PROD
const isDevelopment = import.meta.env.DEV

// Fields that should never be logged
const SENSITIVE_FIELDS = [
  'password',
  'routing_number',
  'routingNumber', 
  'account_number',
  'accountNumber',
  'bank_account_number',
  'bankAccountNumber',
  'signature',
  'access_token',
  'refresh_token',
  'jwt',
  'secret',
  'key',
  'apiKey'
]

/**
 * Recursively sanitize an object, replacing sensitive fields with [REDACTED]
 */
function sanitize(obj: any): any {
  if (obj === null || obj === undefined) return obj
  if (typeof obj !== 'object') return obj
  
  if (Array.isArray(obj)) {
    return obj.map(item => sanitize(item))
  }
  
  const sanitized: any = {}
  for (const [key, value] of Object.entries(obj)) {
    const lowerKey = key.toLowerCase()
    if (SENSITIVE_FIELDS.some(field => lowerKey.includes(field.toLowerCase()))) {
      sanitized[key] = '[REDACTED]'
    } else if (typeof value === 'object') {
      sanitized[key] = sanitize(value)
    } else {
      sanitized[key] = value
    }
  }
  return sanitized
}

/**
 * Safe console.log that sanitizes sensitive data in production
 */
export function log(...args: any[]): void {
  if (isProduction) {
    // In production, only log sanitized data
    const sanitized = args.map(arg => {
      if (typeof arg === 'object') {
        return sanitize(arg)
      }
      return arg
    })
    console.log(...sanitized)
  } else if (isDevelopment) {
    console.log(...args)
  }
}

/**
 * Safe console.error that sanitizes sensitive data
 */
export function error(...args: any[]): void {
  const sanitized = args.map(arg => {
    if (typeof arg === 'object' && arg !== null) {
      return sanitize(arg)
    }
    return arg
  })
  console.error(...sanitized)
}

/**
 * Safe console.warn that sanitizes sensitive data
 */
export function warn(...args: any[]): void {
  if (isProduction) {
    const sanitized = args.map(arg => {
      if (typeof arg === 'object') {
        return sanitize(arg)
      }
      return arg
    })
    console.warn(...sanitized)
  } else {
    console.warn(...args)
  }
}

/**
 * Debug logging - only in development
 */
export function debug(...args: any[]): void {
  if (isDevelopment) {
    console.log('[DEBUG]', ...args)
  }
}
