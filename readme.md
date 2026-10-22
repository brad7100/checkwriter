![PMV](https://drx-danwins.us-east-1.linodeobjects.com/drx-danwins/pmc_51525a39.png) 

# What is this?
Print Me Checks is an open source check printing tool that runs on the web. 

# Goal
The purpose of this project is to provide a free, locally run alternative to check printing tools that exist on the internet. Some of these tools charge $1.25 or more to print a check and you must provide your banking details to a third party. This is silly! This project was literally completed in one day and gets the same job done. 

I buy blank check stock from (insert store here) and then use this tool to print checks for all my businesses with
multiple bank accounts. Works like a charm!

## Screenshot
![PMV](https://drx-danwins.us-east-1.linodeobjects.com/drx-danwins/screencapture-printmechecks-tiiny-site-2024-07-04-07_13_31_(1)_e9e4be02.png)

Simple Vue App for printing checks on 8.5x11 paper.

## Features
* Printing from the Browser
* Fancy signature font (optional)
* Routing and Account number uses official E13B Font
* Run locally to avoid sharing your account number over the internet
* Automatically converts amount of money to english words


# Demo
If you don't want to run the project locally, you can try out the demo version for free. Hosting is not guaranteed to be
up and running in the future though, but I'll keep it up as long as I can. 

[Demo](https://printmechecks.tiiny.site/)

## Requirements
* Node.js 18 or higher
* Supabase account (free tier works)

## ⚠️ SECURITY NOTICE

**If you are upgrading from an older version:**
This project recently underwent a security hardening update. Please review:
- `SECURITY_INCIDENT_RESPONSE.md` - If you were affected by the Railway breach
- `SECURITY_FIXES.md` - For details on security improvements

**Key changes:**
- Supabase credentials are now environment variables (not hardcoded)
- Added input validation, security headers, and secure logging
- Updated vulnerable dependencies

## Setup

### 1. Clone the repository

```sh
git clone https://github.com/brad7100/checkwriter.git
cd checkwriter
```

### 2. Set up Supabase

You need a Supabase project for database and authentication.

1. Create account at [supabase.com](https://supabase.com)
2. Create a new project
3. Run the migrations:
   - Go to SQL Editor in Supabase Dashboard
   - Run `printmechecks/supabase/migrations/20251005_initial_schema.sql`
   - Run `printmechecks/supabase/migrations/001_users_and_permissions.sql`
   - Run `printmechecks/supabase/migrations/002_reenable_rls_for_permissions.sql`
   - Run `printmechecks/supabase/migrations/003_invite_set_password.sql`
4. Make yourself an admin:
   ```sql
   UPDATE public.profiles SET role = 'admin' WHERE email = 'your@email.com';
   ```

### 3. Configure environment variables

```sh
cd printmechecks
cp .env.example .env
```

Edit `.env` and add your Supabase credentials:
```bash
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key-here
```

Get these from Supabase Dashboard → Settings → API

### 4. Install dependencies

```sh
npm install
```

### 5. Run development server

```sh
npm run dev
```

Then go to http://localhost:5173/ in your browser.

**First time setup:**
- You'll be redirected to login
- Sign up with your email
- Verify your email
- Log in
- Make yourself admin (see step 2.4 above)

## Production Deployment

See `RAILWAY_DEPLOYMENT.md` for Railway hosting instructions.

**Environment variables required in production:**
- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_ANON_KEY`

Docker is configured to run the app securely as a non-root user with security headers.

