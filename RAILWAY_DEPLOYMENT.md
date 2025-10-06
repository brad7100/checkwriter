# Railway Deployment Guide

This guide explains how to deploy the CheckWriter application to Railway.

## Prerequisites

1. A Railway account (https://railway.app)
2. Your Supabase project URL and anon key
3. This repository connected to Railway

## Environment Variables

Set these environment variables in your Railway project:

```
VITE_SUPABASE_URL=your_supabase_url_here
VITE_SUPABASE_ANON_KEY=your_supabase_anon_key_here
```

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

- **Port Issues**: The app uses Railway's `$PORT` environment variable
- **Build Failures**: Check that all dependencies are properly installed
- **Environment Variables**: Ensure Supabase credentials are set correctly

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
