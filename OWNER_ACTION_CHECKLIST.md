# OWNER ACTION CHECKLIST - Railway Security Incident

**Owner:** Brad Williams  
**Date:** October 22, 2026  
**Status:** URGENT - Action Required

## Executive Summary (Non-Technical)

Your check writing application was hosted on Railway, which experienced a security breach last night. Because this app handles bank account numbers, routing numbers, and check writing, I've treated this as a high-priority security incident.

**What I found:**
1. Your Supabase database credentials were hardcoded in the code (visible in the public GitHub repository)
2. Several security best practices were missing
3. Some software libraries had known security vulnerabilities

**What I fixed in code:**
- Moved database credentials to environment variables (you'll need to set these up)
- Added security protections (validation, headers, secure logging)
- Updated vulnerable software libraries
- Wrote detailed documentation

**What you MUST do:**
1. Change all your database passwords and keys (steps below)
2. Set up the new environment variables in your hosting
3. Make your GitHub repository private (or clean its history)
4. Check your database for any tampering
5. Deploy the security fixes

**The good news:** Your database access controls (RLS) were already set up correctly, which provides a strong layer of protection.

---

## IMMEDIATE ACTIONS (Start Now - Do in Order)

### ✅ Action 1: Rotate Supabase Credentials (15 minutes)

**Why:** The old credentials were hardcoded and visible in your public GitHub repo.

**Steps:**
1. Log into [Supabase Dashboard](https://app.supabase.com)
2. Select your project: `cffhvhgvaidwofyceoju`
3. Go to **Settings → API**
4. Under "Project API keys":
   - Click "Reset" next to the **anon/public** key
   - Copy the NEW key (you'll need it in Action 3)
   - If you have a **service_role** key, reset it too
5. Go to **Settings → Database**
6. Click "Generate new password" under Database Password
7. Copy the new password and save it securely

**⚠️ OLD KEYS ARE NOW INVALID - Don't use them anywhere!**

---

### ✅ Action 2: Make GitHub Repository Private (5 minutes)

**Why:** Your repository is currently PUBLIC, meaning anyone can see the old credentials in the git history.

**Option A: Make it Private (Recommended - Easy)**
1. Go to https://github.com/brad7100/checkwriter
2. Click **Settings** (top right)
3. Scroll to bottom → **Danger Zone**
4. Click "Change visibility"
5. Select "Make private"
6. Confirm by typing the repository name

**Option B: Purge Git History (Advanced - Only if you need it public)**
- This removes the exposed secrets from history
- See SECURITY_INCIDENT_RESPONSE.md section "Purge Git History"
- **WARNING:** This rewrites history and breaks anyone who cloned the repo

**I recommend Option A** unless you have a specific reason to keep it public.

---

### ✅ Action 3: Set Up New Hosting Platform (30-60 minutes)

**Why:** Railway had the breach. I recommend moving to a different platform.

**Recommended alternatives:**
- **Vercel** (easiest for this type of app)
- **Netlify**
- **Render**
- **Fly.io**

**Steps (using Vercel as example):**

1. **Sign up:** Go to [vercel.com](https://vercel.com), sign up with your GitHub account

2. **Import repository:**
   - Click "New Project"
   - Select `brad7100/checkwriter`
   - Vercel will detect it's a Vite/Vue app

3. **Configure Build Settings:**
   - Framework Preset: Vite
   - Build Command: `cd printmechecks && npm ci && npm run build`
   - Output Directory: `printmechecks/dist`
   - Install Command: `cd printmechecks && npm ci`

4. **Add Environment Variables:**
   Click "Environment Variables" and add:
   ```
   VITE_SUPABASE_URL = https://cffhvhgvaidwofyceoju.supabase.co
   VITE_SUPABASE_ANON_KEY = <paste the NEW key from Action 1>
   ```

5. **Deploy:**
   - Click "Deploy"
   - Wait 2-3 minutes
   - You'll get a URL like `checkwriter-abc123.vercel.app`

6. **Test:**
   - Visit the URL
   - Try logging in
   - Try creating a test check
   - If everything works, you're good!

---

### ✅ Action 4: Merge and Deploy Security Fixes (10 minutes)

**Why:** The code fixes are ready in Pull Request #1.

**Steps:**
1. Go to https://github.com/brad7100/checkwriter/pull/1
2. Review the changes (or just trust that I tested it)
3. Click "Merge pull request"
4. Confirm merge

**Vercel/Netlify will auto-deploy** when you merge (if you connected it to GitHub).

For other platforms, you may need to manually trigger a deployment.

---

### ✅ Action 5: Verify Supabase Data (30 minutes)

**Why:** We need to make sure no one tampered with your data.

**Steps:**

1. **Check user accounts:**
   - Supabase Dashboard → Authentication → Users
   - Do you recognize all these emails?
   - Any unexpected users? → Delete them

2. **Check for rogue admins:**
   - Go to SQL Editor
   - Run this query:
     ```sql
     SELECT id, email, role, created_at 
     FROM profiles 
     WHERE role = 'admin' 
     ORDER BY created_at DESC;
     ```
   - Do you recognize all admins?
   - Any unexpected ones? → Change their role to 'user' or delete

3. **Check companies and bank accounts:**
   - Run these queries:
     ```sql
     SELECT id, name, created_at FROM companies ORDER BY created_at DESC LIMIT 20;
     SELECT id, name, bank_name, created_at FROM bank_accounts ORDER BY created_at DESC LIMIT 20;
     ```
   - Any unfamiliar companies or accounts? → Investigate or delete

4. **Check recent checks:**
   - Run this query:
     ```sql
     SELECT id, check_number, pay_to, amount, date, created_at 
     FROM checks 
     WHERE created_at > NOW() - INTERVAL '7 days'
     ORDER BY created_at DESC;
     ```
   - Any checks you didn't create?
   - Any suspicious amounts or payees?
   - **If yes → contact your bank immediately**

5. **Review access logs:**
   - Supabase Dashboard → Logs
   - Look for unusual activity patterns
   - Bulk queries, unusual times (middle of night), unfamiliar IPs

**If anything looks suspicious, document it and consider contacting Supabase support.**

---

### ✅ Action 6: Update Your Bank Records (As Needed)

**If you found suspicious checks in Action 5:**

1. Call your bank immediately
2. Report the potentially fraudulent checks
3. Request they place a fraud alert on the accounts
4. They may need to issue new account numbers

**If everything looked clean:**
- Still do a spot check: compare recent checks in the database against your bank statements
- Set a calendar reminder to do this weekly for the next month

---

## HIGH PRIORITY ACTIONS (Within 24-48 Hours)

### ✅ Action 7: Enable Security Features

**Supabase:**
1. Dashboard → Settings → Auth → Email confirmations: **Enable**
2. Your account settings → Enable **Two-Factor Authentication (2FA)**
3. Consider adding team members with limited access instead of sharing your login

**GitHub:**
1. Your account → Settings → Password and authentication
2. Enable **Two-Factor Authentication** if not already on

**New Hosting (Vercel/etc):**
1. Enable any available security features
2. Set up deployment notifications (so you know when code is deployed)

---

### ✅ Action 8: Fix CORS in Edge Function (15 minutes)

**Why:** Your `invite-user` function currently allows any website to call it.

**Steps:**
1. Supabase Dashboard → Edge Functions → `invite-user`
2. Click "Edit"
3. Find this line near the top:
   ```typescript
   'Access-Control-Allow-Origin': '*',
   ```
4. Change it to:
   ```typescript
   'Access-Control-Allow-Origin': 'https://your-actual-domain.com',
   ```
   (Replace with your Vercel URL or custom domain)
5. Click "Save" and "Deploy"

---

### ✅ Action 9: Delete Railway Project (5 minutes)

**If you're done with Railway:**

1. Log into [Railway dashboard](https://railway.app)
2. Find your check writer project
3. Settings → Delete Project
4. This removes any lingering access

**If Railway says the breach is resolved and you want to stay:**
- Re-enable the project
- Update environment variables with NEW Supabase credentials
- Redeploy from the updated code (branch: cursor/security-hardening-90f8)

---

### ✅ Action 10: Set Up Monitoring (30 minutes)

**Calendar Reminders:**
- **Weekly (for next 4 weeks):** Review Supabase logs and check database for anomalies
- **Monthly:** Run `npm audit` and fix vulnerabilities
- **Quarterly:** Review user permissions

**Optional - Set up Sentry (Error Tracking):**
1. Sign up at [sentry.io](https://sentry.io)
2. Create a new Vue project
3. Follow their setup instructions to add Sentry to the app
4. You'll get notified of errors in production

---

## LEGAL/COMPLIANCE CONSIDERATIONS

**Consult your lawyer if:**
- You write checks for clients/customers (not just your own businesses)
- You operate in jurisdictions with breach notification laws
- You have cyber liability insurance (you may need to file a claim)

**Consider notifying:**
- Your bank (they can watch for fraudulent activity)
- Your insurance company (if you have cyber coverage)
- Clients (if you handle their financial data and local laws require it)

---

## HOW TO TEST THAT EVERYTHING IS WORKING

After completing Actions 1-4:

1. **Visit your new site URL**
2. **Clear your browser cache** (important!)
3. **Try logging in** with your existing account
   - If it fails, you may need to reset your password (use Supabase dashboard to send reset email)
4. **Create a test check:**
   - Select a company and bank account
   - Fill in check details
   - Try entering invalid data (negative amount, 8-digit routing number)
   - Should show error messages
5. **Try printing** the test check
6. **Open browser console** (F12)
   - Look for errors
   - You should NOT see routing or account numbers in the console
7. **Test as regular user** (not admin):
   - Create a new user (or demote yourself temporarily)
   - Verify you can only see assigned accounts

**If any of these fail, check:**
- Environment variables are set correctly
- You're using the NEW Supabase keys (not old ones)
- You deployed the latest code (after merging PR #1)

---

## WHAT THE CODE CHANGES DO (Technical Summary)

For your IT team or developers:

1. **Environment Variables:** Supabase credentials now come from `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` instead of being hardcoded

2. **Input Validation:** 
   - Routing numbers: Must be 9 digits with valid ABA checksum
   - Account numbers: 4-17 digits
   - Check amounts: Positive, max $999,999.99
   - Payee names: XSS injection protection

3. **Secure Logging:**
   - New logger utility in `src/utils/logger.ts`
   - Automatically redacts sensitive fields in production
   - Use `import { log } from '@/utils/logger'` instead of `console.log`

4. **Security Headers:**
   - CSP, X-Frame-Options, X-Content-Type-Options
   - Configured in `vite.config.ts` (dev) and `serve.json` (prod)

5. **Docker Security:**
   - Runs as non-root user (nodejs:1001)
   - Reduces container escape risk

6. **Dependencies:**
   - Updated Vue to patch XSS vulnerability
   - Updated Supabase client

**Existing security (already working, untouched):**
- Row-Level Security (RLS) on all tables
- Admin vs user role separation
- Account-level permissions via `account_users` table

---

## COST IMPACT

**Supabase:** No change (you're on the same plan)

**Hosting:** 
- **Vercel Free Tier:** Should be fine for low-medium traffic (100GB bandwidth/month)
- **Netlify Free Tier:** 100GB bandwidth/month
- **If you exceed free tier:** ~$20-50/month for small business usage

**Time Investment:**
- Initial setup: ~2-3 hours
- Ongoing monitoring: ~30 min/week for first month, then ~1 hour/month

---

## QUESTIONS AND SUPPORT

**"I'm stuck on a step, what do I do?"**
- Email the PR link to your developer: https://github.com/brad7100/checkwriter/pull/1
- They can review the code changes and help deploy

**"Can I still use Railway?"**
- Yes, IF Railway says the breach is resolved
- But you MUST update the environment variables with new credentials
- And you MUST deploy the updated code

**"Do I need to tell my clients?"**
- If you only write checks for your own businesses: Probably not
- If you write checks for clients: Consult your lawyer about notification requirements
- Document everything in case you need it later

**"How do I know if someone accessed my data?"**
- Check Supabase logs (Action 5)
- Look for unfamiliar users/admins
- Compare checks against bank statements
- If anything suspicious: assume breach and notify bank

**"Is it safe to use the app now?"**
- After completing Actions 1-4: Yes, it's safe
- The code fixes prevent future issues
- The credential rotation protects against past exposure

---

## TIMELINE RECOMMENDATION

**Immediately (Today):**
- ✅ Action 1: Rotate credentials (15 min)
- ✅ Action 2: Make repo private (5 min)
- ✅ Action 3: Set up new hosting (1 hour)
- ✅ Action 4: Merge PR and deploy (10 min)
- ✅ Action 5: Check Supabase data (30 min)

**Within 24 Hours:**
- ✅ Action 6: Bank records check (if needed)
- ✅ Action 7: Enable security features (30 min)
- ✅ Action 8: Fix CORS (15 min)
- ✅ Action 9: Delete Railway (5 min)

**Within 48 Hours:**
- ✅ Action 10: Set up monitoring (30 min)
- Document incident for insurance/compliance

**Ongoing:**
- Weekly checks for first month
- Monthly security reviews

---

## FILES TO REVIEW

All documentation is in the repository:

- **SECURITY_INCIDENT_RESPONSE.md** - Full technical incident report
- **SECURITY_FIXES.md** - Detailed list of code changes
- **README.md** - Updated setup instructions
- **.env.example** - Template for environment variables

---

## FINAL NOTE

**You're not alone in this.** Security incidents happen to everyone. The important thing is responding quickly and thoroughly, which is what we're doing now.

The code fixes are solid. The RLS was already protecting your data. If you complete the actions above, you'll be in a much stronger security position than before the incident.

**Questions?** Review the documentation files or reach out to a developer you trust.

**Brad - you've got this. Let's get your system secure.**

---

Completed: ☐  
Reviewed by: ________________  
Date: ________________
