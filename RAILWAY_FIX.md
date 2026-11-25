# Railway Deployment Fix - "Invalid API Key" Error

**Issue Date:** October 30, 2026  
**Status:** ⚠️ REQUIRES MANUAL CONFIGURATION IN RAILWAY DASHBOARD

## Root Cause Analysis

The deployed CheckPrint app shows "Invalid API key" because **Railway is not passing the Supabase environment variables as Docker build arguments**.

### Technical Details

1. ✅ **Code is correct**: The Dockerfile (updated Oct 22) properly declares `ARG` and `ENV` for Vite variables
2. ✅ **Supabase is healthy**: Project `cffhvhgvaidwofyceoju` is active, anon key is valid (iat Oct 2025)
3. ❌ **Railway configuration incomplete**: Environment variables need to be set in Railway dashboard

### Why This Happens

Vite environment variables (`VITE_*`) are **baked into the JavaScript bundle at build time**, not runtime. The Dockerfile correctly uses:

```dockerfile
ARG VITE_SUPABASE_URL
ARG VITE_SUPABASE_ANON_KEY
ENV VITE_SUPABASE_URL=$VITE_SUPABASE_URL
ENV VITE_SUPABASE_ANON_KEY=$VITE_SUPABASE_ANON_KEY
```

But Railway needs these variables configured in the **service settings** to pass them as build arguments.

---

## Fix Instructions for Brad

### Option 1: Configure Railway (If Staying with Railway)

**Time Required:** 5-10 minutes

1. **Log into Railway Dashboard**
   - Go to https://railway.app
   - Select your CheckWriter project/service

2. **Add Environment Variables**
   - Click on your service
   - Go to **Variables** tab
   - Add these two variables:

   ```
   VITE_SUPABASE_URL=https://cffhvhgvaidwofyceoju.supabase.co
   VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNmZmh2aGd2YWlkd29meWNlb2p1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk2ODUwOTMsImV4cCI6MjA3NTI2MTA5M30.AXL9vIG4i_SlNPFq-211HoR_PubKg1TtCHo4kWR6kPU
   ```

   ⚠️ **IMPORTANT**: Make sure there are no leading/trailing spaces or quotes around the values

3. **Trigger a Rebuild**
   - **Critical**: You must trigger a **new build**, not just a redeploy
   - Go to **Deployments** tab
   - Click **⋮** (three dots) on the latest deployment
   - Select **Redeploy** or **Trigger Deploy**
   - OR: Push a small commit to trigger automatic rebuild

4. **Verify the Build**
   - Watch the build logs
   - Look for: "Building application..." 
   - The build should complete without the "Missing Supabase environment variables" error

5. **Test**
   - Visit your Railway deployment URL
   - Try logging in
   - Should work now! ✅

---

### Option 2: Move to Another Platform (Recommended After Security Incident)

Given the Railway security incident mentioned in `OWNER_ACTION_CHECKLIST.md`, you may want to migrate to a different platform. All of these handle Vite environment variables correctly:

#### **Vercel** (Recommended - Easiest)

1. Go to https://vercel.com
2. Sign in with GitHub
3. Click "New Project" → Import `brad7100/checkwriter`
4. **Framework Preset**: Vite
5. **Build Command**: `cd printmechecks && npm ci && npm run build`
6. **Output Directory**: `printmechecks/dist`
7. **Environment Variables**:
   ```
   VITE_SUPABASE_URL=https://cffhvhgvaidwofyceoju.supabase.co
   VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNmZmh2aGd2YWlkd29meWNlb2p1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk2ODUwOTMsImV4cCI6MjA3NTI2MTA5M30.AXL9vIG4i_SlNPFq-211HoR_PubKg1TtCHo4kWR6kPU
   ```
8. Click **Deploy**
9. You'll get a URL like `checkwriter-xyz.vercel.app`

#### **Netlify**

1. Go to https://netlify.com
2. Click "Add new site" → "Import an existing project"
3. Connect to GitHub → Select `brad7100/checkwriter`
4. **Build command**: `cd printmechecks && npm ci && npm run build`
5. **Publish directory**: `printmechecks/dist`
6. **Environment variables**: Same as above
7. Click **Deploy**

#### **Render**

1. Go to https://render.com
2. New → Static Site
3. Connect repository
4. **Build Command**: `cd printmechecks && npm ci && npm run build`
5. **Publish Directory**: `printmechecks/dist`
6. **Environment Variables**: Same as above
7. Create Static Site

---

## What Changed in the Code (Already Fixed)

The October 22 commits added these lines to the Dockerfile:

```dockerfile
# Declare build arguments for Vite environment variables
ARG VITE_SUPABASE_URL
ARG VITE_SUPABASE_ANON_KEY
ENV VITE_SUPABASE_URL=$VITE_SUPABASE_URL
ENV VITE_SUPABASE_ANON_KEY=$VITE_SUPABASE_ANON_KEY
```

This allows Docker to receive the variables from Railway and pass them to Vite during the build process.

**No code changes needed** - the repository is ready. You just need to configure the hosting platform.

---

## Why "Invalid API Key" Appears

When the environment variables are missing during build:

1. Vite reads `import.meta.env.VITE_SUPABASE_URL` → gets `undefined`
2. Vite reads `import.meta.env.VITE_SUPABASE_ANON_KEY` → gets `undefined`
3. The app throws "Missing Supabase environment variables" error OR
4. The app tries to use `undefined` as the API key → Supabase returns "Invalid API key"

The security fix on Oct 22 added proper error handling, so the app should throw the "Missing" error if variables aren't set. If you're seeing "Invalid API key" instead, it might mean:

- Variables are set but **wrong values** (copy/paste error, extra spaces)
- Variables were set but the app was **redeployed without rebuilding**
- Old cached build is being served

---

## Verification Steps

After configuring Railway or deploying to a new platform:

1. **Check Build Logs**
   - Should NOT see "Missing Supabase environment variables"
   - Build should complete successfully

2. **Check Runtime Logs**
   - Visit the deployment URL
   - Open browser console (F12)
   - Should NOT see "Missing Supabase environment variables" error
   - Should NOT see "Invalid API key" error

3. **Test Login**
   - Try logging in with your email/password
   - Should successfully authenticate
   - Dashboard should load

4. **Test Check Creation**
   - Try creating a test check
   - Should save to Supabase
   - Should be able to print

---

## Common Mistakes to Avoid

❌ **DON'T** set the variables with quotes:
```
VITE_SUPABASE_ANON_KEY="eyJhbGc..."  ← WRONG
```

✅ **DO** set them without quotes:
```
VITE_SUPABASE_ANON_KEY=eyJhbGc...  ← CORRECT
```

❌ **DON'T** just redeploy the same build:
- Redeploying uses the already-built Docker image
- Variables are baked in at **build time**, not deploy time

✅ **DO** trigger a new build:
- Push a new commit, OR
- Use "Redeploy" which rebuilds from scratch

❌ **DON'T** put variables in `.env` and commit them:
- They won't be in production (`.env` is gitignored)
- Security risk if accidentally committed

✅ **DO** set them in your hosting platform's dashboard:
- Railway: Variables tab
- Vercel: Project Settings → Environment Variables
- Netlify: Site settings → Build & deploy → Environment

---

## If It Still Doesn't Work

1. **Check the actual values being used**:
   - Build logs should show ARG values being set (Railway masks them, so you'll see `***`)
   - If you don't see ARG messages, variables aren't being passed

2. **Verify Supabase project**:
   - Go to https://app.supabase.com/project/cffhvhgvaidwofyceoju
   - Check Settings → API
   - Verify the URL and anon key match exactly

3. **Check for browser caching**:
   - Clear browser cache and cookies
   - Try in incognito/private mode
   - Hard refresh (Ctrl+Shift+R or Cmd+Shift+R)

4. **Test the Supabase key directly**:
   ```bash
   curl https://cffhvhgvaidwofyceoju.supabase.co/auth/v1/settings \
     -H "apikey: eyJhbGc..." \
     -H "Authorization: Bearer eyJhbGc..."
   ```
   Should return 200 OK with settings JSON

---

## Contact Information

**Supabase Project**: `cffhvhgvaidwofyceoju`  
**Project URL**: https://cffhvhgvaidwofyceoju.supabase.co  
**Project Status**: ✅ ACTIVE_HEALTHY  
**Anon Key iat**: October 2025 (valid, not expired)

**Railway Project**: [Your Railway project name]  
**Current Deployment**: Uses Dockerfile builder  

---

## Security Note

The anon key shown in this document is the **public anon key**, which is safe to expose client-side (it's embedded in your JavaScript bundle). It's protected by Row-Level Security (RLS) policies in Supabase.

However, per the October 22 security fixes, you should:
- Keep this repository **private** (or rotate keys if public)
- NEVER commit `.env` files
- Use environment variables in hosting platforms

See `SECURITY_FIXES.md` and `OWNER_ACTION_CHECKLIST.md` for full security guidance.

---

## Summary

✅ **Code**: Fixed (Oct 22 commits)  
✅ **Supabase**: Healthy and working  
❌ **Railway Config**: Needs environment variables set  
⚠️ **Action Required**: Set variables in Railway dashboard, then **rebuild** (not just redeploy)

**Estimated Fix Time**: 5-10 minutes  
**Estimated Migration Time** (if moving platforms): 15-30 minutes
