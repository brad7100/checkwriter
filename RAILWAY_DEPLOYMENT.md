# Railway Deployment Guide

This guide explains how to deploy the CheckWriter application to Railway.

## Prerequisites

1. A Railway account (https://railway.app)
2. Your Supabase project URL and anon key
3. This repository connected to Railway

## Environment Variables

**CRITICAL**: These environment variables MUST be set in Railway's dashboard for the app to work.

In Railway Dashboard → Your Service → Variables tab, add:

```
VITE_SUPABASE_URL=https://cffhvhgvaidwofyceoju.supabase.co
VITE_SUPABASE_ANON_KEY=your_actual_anon_key_here
```

**Important Notes**:
- Do NOT include quotes around the values
- Do NOT add spaces before/after the values  
- After adding variables, you MUST trigger a **rebuild** (not just redeploy)
- These are build-time variables that get baked into the JavaScript bundle

Railway automatically passes service variables as Docker build arguments when using `"builder": "DOCKERFILE"`. The Dockerfile declares these as `ARG` and `ENV` to make them available during the Vite build process.

## Deployment Steps

1. **Connect Repository**: Connect your GitHub repository to Railway
2. **Set Environment Variables**: Add the Supabase environment variables
3. **Deploy**: Railway will automatically detect the Node.js configuration and deploy

## Project Structure

- Root `package.json` - Railway entry point
- `printmechecks/` - Vue.js application directory
- `railway.json` - Railway configuration
- `nixpacks.toml` - Build configuration
- `start.sh` - Startup script

## Build Process

1. Railway installs dependencies in the `printmechecks/` directory
2. Builds the Vue.js application using `npm run build`
3. Starts the preview server using `npm run preview`

## Troubleshooting

### "Invalid API key" or "Missing Supabase environment variables" Error

**Cause**: Environment variables not set in Railway, or deployment used old build.

**Solution**:
1. Verify variables are set in Railway Dashboard → Variables tab
2. Ensure no quotes or spaces in the values
3. Trigger a **new build** (not just redeploy):
   - Go to Deployments → Click ⋮ → Redeploy
   - OR push a new commit to trigger auto-rebuild
4. Check build logs to confirm variables were passed

**Why this happens**: Vite embeds `VITE_*` variables at build time. Redeploying the same Docker image won't pick up new variables - you need a fresh build.

### Port Issues

The app uses Railway's `$PORT` environment variable (automatically set by Railway).

### Build Failures

- Check that all dependencies are properly installed
- Review build logs for specific error messages
- Ensure `printmechecks/package.json` exists and is valid

### Environment Variables Not Working

Common mistakes:
- ❌ Adding quotes: `VITE_SUPABASE_URL="https://..."`
- ❌ Just redeploying instead of rebuilding  
- ❌ Setting variables in `.env` instead of Railway dashboard
- ✅ Set in Railway Variables tab, no quotes, then rebuild

## Local Development

To run locally:
```bash
cd printmechecks
npm install
npm run dev
```

## Production Build

To build for production:
```bash
cd printmechecks
npm run build
npm run preview
```
