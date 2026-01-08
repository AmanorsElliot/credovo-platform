# Lovable Environment Variables Checklist

## ✅ Required Variables

### 1. `REACT_APP_API_URL` ✅ **YOU'VE ADDED THIS**
- **Value**: `https://orchestration-service-saz24fo3sa-ew.a.run.app`
- **Status**: ✅ Configured
- **Purpose**: Backend API endpoint

## 🔍 Check These (Usually Auto-Configured by Lovable)

Lovable typically auto-configures these when you set up Supabase authentication. **Check if they exist in your Lovable project settings:**

### 2. `REACT_APP_SUPABASE_URL` (Check if exists)
- **Status**: Usually auto-set by Lovable
- **How to check**: 
  1. Go to Lovable → Project Settings → Environment Variables
  2. Look for `REACT_APP_SUPABASE_URL`
  3. If it exists: ✅ You're good!
  4. If it doesn't exist: Add it manually (see below)

### 3. `REACT_APP_SUPABASE_ANON_KEY` (Check if exists)
- **Status**: Usually auto-set by Lovable
- **How to check**: 
  1. Go to Lovable → Project Settings → Environment Variables
  2. Look for `REACT_APP_SUPABASE_ANON_KEY`
  3. If it exists: ✅ You're good!
  4. If it doesn't exist: Add it manually (see below)

## 📝 If Supabase Variables Are Missing

If you checked and the Supabase variables don't exist, add them:

### Get Values from Supabase Dashboard

1. Go to https://supabase.com/dashboard
2. Select your project
3. Go to **Settings** → **API**
4. Copy:
   - **Project URL** → Use for `REACT_APP_SUPABASE_URL`
   - **anon public** key → Use for `REACT_APP_SUPABASE_ANON_KEY`

### Add to Lovable

1. Go to https://lovable.dev
2. Navigate to **Project Settings** → **Environment Variables**
3. Click **Add Variable**
4. Add:
   - Name: `REACT_APP_SUPABASE_URL`
   - Value: `https://your-project-id.supabase.co`
5. Click **Add Variable** again
6. Add:
   - Name: `REACT_APP_SUPABASE_ANON_KEY`
   - Value: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...` (your anon key)

## ✅ Quick Verification

**You need:**
- ✅ `REACT_APP_API_URL` - **You've added this!**
- ⚠️ `REACT_APP_SUPABASE_URL` - **Check if it exists**
- ⚠️ `REACT_APP_SUPABASE_ANON_KEY` - **Check if it exists**

**If all 3 exist, you're all set!** 🎉

## 🧪 Test Your Setup

Once all variables are configured:

1. **Test API connection** in your Lovable app:
   ```typescript
   const response = await fetch(`${process.env.REACT_APP_API_URL}/health`);
   console.log(await response.json()); // Should return {"status":"ok"}
   ```

2. **Test authentication**:
   - Login with Supabase
   - Get JWT token from session
   - Make authenticated API request

## Summary

- ✅ **REACT_APP_API_URL**: Added
- ⚠️ **REACT_APP_SUPABASE_URL**: Check if auto-set, add if missing
- ⚠️ **REACT_APP_SUPABASE_ANON_KEY**: Check if auto-set, add if missing

Most likely, Lovable already set the Supabase variables when you configured Supabase auth. Just double-check they exist!

