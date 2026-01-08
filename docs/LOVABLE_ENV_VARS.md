# Lovable Frontend Environment Variables

## Required Variables

### ✅ 1. `REACT_APP_API_URL` (REQUIRED - You've added this)
- **Value**: `https://orchestration-service-saz24fo3sa-ew.a.run.app`
- **Purpose**: Backend API endpoint for the orchestration service
- **Status**: ✅ Configured

## Optional Variables (Usually Auto-Configured by Lovable)

Lovable typically auto-configures these when you set up Supabase authentication. **Only add them manually if Lovable didn't auto-set them.**

### 2. `REACT_APP_SUPABASE_URL` (Optional - Usually Auto-Set)
- **When to add**: Only if Lovable didn't automatically set it when you configured Supabase
- **Value**: Your Supabase project URL
- **Example**: `https://your-project-id.supabase.co`
- **Where to find**: Supabase Dashboard → Settings → API → Project URL
- **How to check**: In your Lovable project, go to Project Settings → Environment Variables and see if it's already there

### 3. `REACT_APP_SUPABASE_ANON_KEY` (Optional - Usually Auto-Set)
- **When to add**: Only if Lovable didn't automatically set it when you configured Supabase
- **Value**: Your Supabase anon/public key
- **Where to find**: Supabase Dashboard → Settings → API → Project API keys → `anon` `public`
- **How to check**: In your Lovable project, go to Project Settings → Environment Variables and see if it's already there

## How to Verify

1. Go to your Lovable project: https://lovable.dev
2. Navigate to **Project Settings** → **Environment Variables**
3. Check if these variables exist:
   - ✅ `REACT_APP_API_URL` (you've added this)
   - `REACT_APP_SUPABASE_URL` (check if it exists)
   - `REACT_APP_SUPABASE_ANON_KEY` (check if it exists)

## Summary

**You only need to add manually:**
- ✅ `REACT_APP_API_URL` - **Already added!**

**Check if these exist (usually auto-set):**
- `REACT_APP_SUPABASE_URL` - Check in Lovable settings
- `REACT_APP_SUPABASE_ANON_KEY` - Check in Lovable settings

If the Supabase variables are missing and your Supabase auth isn't working, add them manually using the values from your Supabase dashboard.

