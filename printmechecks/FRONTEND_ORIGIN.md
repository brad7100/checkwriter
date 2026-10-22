# Frontend Origin Configuration

## Production Frontend URL

**To find the production frontend URL**, check one of these locations:

1. **Supabase Dashboard** → Authentication → URL Configuration → Site URL
2. **Deployment platform** (Railway, Vercel, Netlify, etc.) → Environment → Domain
3. **Environment variables** in your deployment: Check for `VITE_APP_URL` or similar

## Common Deployment Patterns

Based on the codebase structure (Vue 3 + Vite), the app is likely deployed on one of:

- **Railway**: `https://printmechecks-production.up.railway.app` (or custom domain)
- **Vercel**: `https://printmechecks.vercel.app` (or custom domain)  
- **Netlify**: `https://printmechecks.netlify.app` (or custom domain)

## Required Configuration

### Edge Function Environment Variable

Set `ALLOWED_ORIGIN` in Supabase Dashboard:

```
ALLOWED_ORIGIN=https://your-actual-frontend-domain.com
```

**⚠️ CRITICAL**: 
- If `ALLOWED_ORIGIN` is **NOT** set, the edge function **DENIES all cross-origin requests**
- This is secure by default - the function will log an error and reject requests
- **Never** use `*` for ALLOWED_ORIGIN in production

### Steps to Configure

1. Find your frontend URL from deployment platform
2. Go to Supabase Dashboard → Edge Functions → `submit-check` → Settings
3. Add environment variable:
   - **Name**: `ALLOWED_ORIGIN`
   - **Value**: `https://your-frontend-domain.com` (no trailing slash)
4. Redeploy the edge function: `supabase functions deploy submit-check`

### Testing CORS

Test with curl after deployment:

```bash
# Should succeed (from allowed origin)
curl -X POST \
  https://your-project.supabase.co/functions/v1/submit-check \
  -H "Origin: https://your-frontend-domain.com" \
  -H "X-Submitter-Key: test-key" \
  -H "Content-Type: application/json" \
  -d '{"test": true}'

# Should fail (cross-origin when ALLOWED_ORIGIN not set)
curl -X POST \
  https://your-project.supabase.co/functions/v1/submit-check \
  -H "Origin: https://attacker-site.com" \
  -H "X-Submitter-Key: test-key" \
  -H "Content-Type: application/json" \
  -d '{"test": true}'
```

Expected response when CORS denied: Browser will block, or function returns with `Access-Control-Allow-Origin: null`

## Default Behavior

- **ALLOWED_ORIGIN set**: Only that origin can call the function
- **ALLOWED_ORIGIN not set**: ALL cross-origin requests denied (`Access-Control-Allow-Origin: null`)
- **Development**: Set to `http://localhost:5173` (Vite dev server) for local testing

## Security Notes

- The edge function is secure by default (denies cross-origin when misconfigured)
- Bot API keys are hashed (SHA-256) and never stored in plain text
- CORS prevents unauthorized web apps from calling the function
- Bot submissions still require valid API key even if CORS allows the request
