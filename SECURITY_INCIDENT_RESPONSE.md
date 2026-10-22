# Security Incident Response - Railway Breach

**Date of Incident:** [Last Night]  
**System Affected:** Check Writing Application  
**Severity:** CRITICAL

## Executive Summary

This document outlines the security breach involving Railway hosting, findings from the security audit, remediation steps taken in code, and immediate actions required by the owner.

## Incident Details

### What Happened
- Railway hosting platform experienced a security breach
- This check writing application was hosted on Railway
- The application handles sensitive financial data: bank routing numbers, account numbers, payee information, and check creation

### What Was Potentially Compromised
Any credentials and secrets that were:
1. **Stored in Railway environment variables** (Supabase credentials, any API keys)
2. **Committed to this GitHub repository** (repository is PUBLIC)
3. **Stored in git history** (Supabase anon key was hardcoded in commit fd22455)

## Critical Security Findings

### 🔴 CRITICAL ISSUES FOUND

1. **Hardcoded Supabase Credentials (FIXED)**
   - **Location:** `printmechecks/src/lib/supabase.ts`
   - **Exposed in commits:** fd22455 (2026-03-07) and all commits after
   - **What was exposed:**
     - Supabase URL: `https://cffhvhgvaidwofyceoju.supabase.co`
     - Supabase Anon Key: `eyJhbGci...` (full JWT - first 8 chars: eyJhbGci)
   - **Risk:** Anyone with repo access can read/write to your database
   - **Status:** FIXED - moved to environment variables

2. **Public GitHub Repository**
   - **Risk:** All code and git history are publicly visible
   - **Implication:** Anyone can see the hardcoded secrets from git history
   - **Status:** REQUIRES OWNER ACTION

3. **No Input Validation on Financial Data**
   - Routing numbers and account numbers accepted without validation
   - Check amounts not validated for reasonable ranges
   - **Status:** PARTIALLY FIXED - validation added

4. **Excessive Console Logging**
   - Sensitive data (routing numbers, account numbers) logged to browser console
   - Production logs could expose financial data
   - **Status:** FIXED - secure logger added

5. **Missing Security Headers**
   - No CSP, X-Frame-Options, or other security headers
   - **Status:** FIXED - headers added to Vite and Dockerfile

6. **Vulnerable Dependencies**
   - Vue XSS vulnerability (CVE-2024-xxxx)
   - Multiple ReDoS vulnerabilities
   - **Status:** FIXED - dependencies updated

7. **Database Access (RLS Enabled - GOOD)**
   - Row-Level Security IS enabled and configured correctly
   - Admin vs user permissions properly enforced
   - **Status:** VERIFIED SECURE

### ⚠️ MODERATE ISSUES FOUND

8. **No Rate Limiting**
   - No protection against brute force attacks
   - **Status:** REQUIRES HOSTING-LEVEL SOLUTION

9. **Edge Function Has CORS Wide Open**
   - `invite-user` function allows `Access-Control-Allow-Origin: *`
   - **Status:** NOTED - needs Supabase Dashboard fix

## What Was Fixed in Code

### ✅ Changes Made in PR #XXX (Branch: cursor/security-hardening-90f8)

1. **Moved secrets to environment variables**
   - Created `.env.example` with instructions
   - Updated `.gitignore` to block `.env` files
   - Modified `supabase.ts` to use `import.meta.env` variables

2. **Added Security Headers**
   - Updated `vite.config.ts` with CSP, X-Frame-Options, etc.
   - Modified `Dockerfile` to run as non-root user
   - Added security headers configuration

3. **Created Secure Logger**
   - New `utils/logger.ts` sanitizes sensitive fields
   - Redacts routing numbers, account numbers, passwords in logs
   - Only logs in development; sanitizes in production

4. **Updated Vulnerable Dependencies**
   - Fixed Vue XSS vulnerability
   - Updated Supabase client
   - Resolved high-severity npm audit issues

5. **Improved `.gitignore`**
   - Added entries for `.env*`, `.pem`, `.key`, `secrets/`, etc.

6. **Input Validation (Partial)**
   - Added format checks for routing numbers (9 digits)
   - Added validation for account numbers
   - Check amounts validated for numeric input

7. **Added Documentation**
   - Created `.env.example` with setup instructions
   - Updated security notes in README

## IMMEDIATE ACTIONS REQUIRED (Owner Must Do)

### 🚨 DO THESE IMMEDIATELY

1. **Rotate Supabase Credentials**
   - Go to Supabase Dashboard → Settings → API
   - **Generate NEW anon key** (mark old one as compromised)
   - **Reset service role key** (if you had one in Railway)
   - Update these in your NEW hosting platform (not Railway)

2. **Change Supabase Database Password**
   - Supabase Dashboard → Settings → Database → Database Password
   - Click "Generate new password" or set a strong one
   - Update connection strings in any external tools

3. **Make Repository Private**
   - GitHub: brad7100/checkwriter → Settings → Danger Zone
   - Click "Change visibility" → Make Private
   - **OR** purge git history (see step 6 below) if you want to keep it public

4. **Set Environment Variables in New Hosting**
   - **DO NOT use Railway anymore until confirmed safe**
   - In your new hosting platform (Vercel, Netlify, Render, fly.io):
     ```
     VITE_SUPABASE_URL=https://cffhvhgvaidwofyceoju.supabase.co
     VITE_SUPABASE_ANON_KEY=<NEW_KEY_FROM_STEP_1>
     ```
   - Deploy from the security branch (cursor/security-hardening-90f8)

5. **Review Railway Dashboard**
   - Check Railway logs for any suspicious access
   - Check Railway metrics for unexpected traffic spikes
   - If Railway offers breach notification details, review them
   - **Delete the Railway project** if you're migrating away

6. **[OPTIONAL BUT RECOMMENDED] Purge Git History**
   - If you want to keep the repo public, you must remove the exposed secret from history
   - **WARNING:** This rewrites history and breaks anyone who cloned the repo
   - Use BFG Repo-Cleaner or `git filter-repo`:
     ```bash
     # Install BFG: https://rtyley.github.io/bfg-repo-cleaner/
     bfg --replace-text secrets.txt checkwriter.git
     cd checkwriter.git
     git reflog expire --expire=now --all
     git gc --prune=now --aggressive
     git push --force
     ```
   - Where `secrets.txt` contains:
     ```
     eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNmZmh2aGd2YWlkd29meWNlb2p1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk2ODUwOTMsImV4cCI6MjA3NTI2MTA5M30.AXL9vIG4i_SlNPFq-211HoR_PubKg1TtCHo4kWR6kPU==>**REDACTED**
     ```

### 🔍 DO THESE SOON (Within 24-48 Hours)

7. **Audit Supabase Access Logs**
   - Supabase Dashboard → Logs
   - Look for:
     - Unusual query patterns
     - Bulk data exports
     - Access from unfamiliar IPs
     - Failed authentication attempts
   - Check table row counts: do `companies`, `bank_accounts`, `checks` have unexpected changes?

8. **Check Financial Records**
   - Compare checks in the database against your actual bank records
   - Look for:
     - Checks you didn't create
     - Modified check amounts
     - Changed routing/account numbers
     - Unfamiliar payees
   - **If you find discrepancies, contact your bank immediately**

9. **Review User Access**
   - Supabase Dashboard → Authentication → Users
   - Verify all listed users are legitimate
   - Check `profiles` table for unexpected admin accounts:
     ```sql
     SELECT * FROM profiles WHERE role = 'admin';
     ```
   - If you find unknown admins, delete them and rotate credentials again

10. **Enable Supabase Security Features**
    - Enable email confirmations (if not already on)
    - Set up 2FA for your Supabase account
    - Review and tighten RLS policies if needed (current ones look good)
    - Enable database backups if not already configured

11. **Update Edge Function CORS**
    - Supabase Dashboard → Edge Functions → invite-user
    - Change `Access-Control-Allow-Origin` from `*` to your actual domain
    - Redeploy the function

### 📋 MONITORING GOING FORWARD

12. **Set Up Monitoring**
    - Enable Supabase email alerts for auth changes
    - Set up Sentry or similar for error tracking
    - Monitor Railway (if you stay) or new platform logs weekly
    - Check your bank statements weekly for unauthorized checks

13. **Regular Security Reviews**
    - Run `npm audit` monthly and fix vulnerabilities
    - Review Supabase logs monthly
    - Update dependencies quarterly
    - Review user permissions quarterly

## What You Should Tell Your Team

If you have employees or contractors who use this system:

1. "We experienced a security incident affecting our check writing system"
2. "All credentials have been rotated as a precaution"
3. "Please verify any checks written in the past [X days] against bank records"
4. "Report any unusual check activity immediately"
5. "Do not share login credentials via email or text"

## Technical Architecture (For Your IT Team)

### Current Setup
- **Frontend:** Vue 3 + TypeScript, built with Vite
- **Backend/Database:** Supabase (PostgreSQL with RLS)
- **Hosting:** Railway (Docker container, Dockerfile provided)
- **Authentication:** Supabase Auth (email/password)
- **Repository:** GitHub, currently PUBLIC

### Security Posture After Fixes
- ✅ Secrets moved to environment variables
- ✅ RLS enabled on all tables
- ✅ Admin/user role separation enforced
- ✅ Security headers configured
- ✅ Vulnerable dependencies patched
- ✅ Non-root Docker user
- ✅ Secure logging implemented
- ⚠️ Rate limiting: needs hosting-level config
- ⚠️ CORS: needs Supabase edge function update

### How Authentication Works
- Users authenticate via Supabase Auth
- JWT tokens are stored in browser (httpOnly would be better but not supported by Supabase client-side)
- RLS policies enforce data access:
  - Admins can see all companies/accounts
  - Regular users only see accounts they're assigned to via `account_users` table
  - Check creation requires account access

### How Data Is Protected
- Database enforces RLS: queries automatically filtered by user permissions
- Bank account numbers and routing numbers stored in plain text (consider encryption at rest)
- Signatures are text strings (consider storing as encrypted images)
- No PCI DSS compliance (checks are not credit card transactions, but still sensitive)

## Compliance and Legal Considerations

**⚠️ CONSULT YOUR LAWYER REGARDING:**

1. **Breach Notification Laws**
   - Some jurisdictions require notification if personal data (names, addresses) is compromised
   - Varies by state and country

2. **Client Notification**
   - If you write checks for clients/customers, they may need to be informed
   - Depends on your service agreements and local laws

3. **Bank Notification**
   - Consider notifying your bank of the potential compromise
   - They can flag accounts for monitoring

4. **Insurance**
   - If you have cyber liability insurance, file a claim
   - Document all remediation steps

## Questions and Support

**For technical questions about this PR:**
- Review the code changes in cursor/security-hardening-90f8
- See `.env.example` for environment setup
- Contact your development team

**For Supabase questions:**
- Supabase Documentation: https://supabase.com/docs
- Supabase Support: Dashboard → Help & Support

**For Railway incident questions:**
- Check Railway's status page and incident reports
- Contact Railway support for specifics on the breach

## Summary

### What We Know Was Exposed
1. Supabase URL and anon key (hardcoded in public repo)
2. Application source code (public repo)
3. Potentially: Railway environment variables (unknown scope of Railway breach)

### What We Don't Know
1. Whether attackers accessed your specific Railway project
2. Whether database was accessed using the exposed credentials
3. Whether check data was viewed or exfiltrated

### Assume Worst Case
- Treat all credentials as compromised
- Rotate everything
- Audit all data for tampering
- Monitor closely for next 30-60 days

---

**This incident is serious but manageable. The code fixes are in place. The owner actions above will secure the system going forward.**
