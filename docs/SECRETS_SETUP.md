# Secrets Setup Guide

## GCP Secret Manager Setup

Run these commands in PowerShell to configure secrets in GCP. Make sure you're authenticated and have the necessary permissions.

### Prerequisites

```powershell
# Set your GCP project
gcloud config set project credovo-eu-apps-nonprod

# Verify you have Secret Manager Admin role
# If you get permission errors, ask your GCP admin to grant you:
# roles/secretmanager.admin or roles/secretmanager.secretAccessor
```

### Required Secrets

#### 1. Supabase URL (REQUIRED)

```powershell
# Replace with your actual Supabase project URL
# Get this from: Supabase Dashboard → Settings → API → Project URL
# Example: https://jywjbinndnanxscxqdes.supabase.co
$supabaseUrl = "https://jywjbinndnanxscxqdes.supabase.co"  # Replace with your URL
$supabaseUrl | gcloud secrets versions add supabase-url --data-file=-
```

**Note**: The backend automatically constructs the JWKS endpoint: `{SUPABASE_URL}/auth/v1/.well-known/jwks.json`

#### 2. Service JWT Secret (REQUIRED - Auto-generated)

```powershell
# Generate a secure random secret
$jwtSecret = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 64 | ForEach-Object {[char]$_})
$jwtSecretBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($jwtSecret))
$jwtSecretBase64 | gcloud secrets versions add service-jwt-secret --data-file=-
```

### Optional Secrets

#### 3. Lovable JWKS URI (Optional - only if not using Supabase)

```powershell
$jwksUri = "https://auth.lovable.dev/.well-known/jwks.json"
$jwksUri | gcloud secrets versions add lovable-jwks-uri --data-file=-
```

#### 4. Lovable Audience (Optional - only if not using Supabase)

```powershell
$audience = "credovo-api"
$audience | gcloud secrets versions add lovable-audience --data-file=-
```

#### 5. SumSub API Key (Optional)

```powershell
# Get from SumSub Dashboard
$sumsubKey = "your-sumsub-api-key"
$sumsubKey | gcloud secrets versions add sumsub-api-key --data-file=-
```

#### 6. Companies House API Key (Optional)

```powershell
# Get from Companies House Developer Hub
$companiesHouseKey = "your-companies-house-api-key"
$companiesHouseKey | gcloud secrets versions add companies-house-api-key --data-file=-
```

### Verify Secrets

```powershell
# List all secrets
gcloud secrets list

# View a specific secret (first few characters only for security)
gcloud secrets versions access latest --secret=supabase-url
gcloud secrets versions access latest --secret=service-jwt-secret | Select-Object -First 20
```

### Troubleshooting Permission Errors

If you get `PERMISSION_DENIED` errors:

1. **Check your authentication:**
   ```powershell
   gcloud auth list
   gcloud config get-value project
   ```

2. **Request permissions from GCP admin:**
   - Role needed: `roles/secretmanager.admin` or `roles/secretmanager.secretAccessor`
   - Or ask admin to run the commands for you

3. **Alternative: Use Terraform to create secrets first:**
   ```powershell
   cd infrastructure/terraform
   terraform apply  # This creates secret placeholders
   # Then add values using gcloud commands above
   ```

---

## Lovable Frontend Environment Variables

Configure these in your Lovable project settings:

### Required Variables

1. **`REACT_APP_API_URL`**
   - **Value**: Your orchestration service URL
   - **How to get**: 
     ```powershell
     cd infrastructure/terraform
     terraform output orchestration_service_url
     ```
   - **Example**: `https://orchestration-service-aoyifnsw4a-ew.a.run.app`

### Supabase Variables (Usually Auto-configured by Lovable)

If Lovable doesn't automatically set these when you configure Supabase, add them manually:

2. **`REACT_APP_SUPABASE_URL`** (if not auto-set)
   - **Value**: Your Supabase project URL
   - **Example**: `https://your-project-id.supabase.co`
   - **Where to find**: Supabase Dashboard → Settings → API → Project URL

3. **`REACT_APP_SUPABASE_ANON_KEY`** (if not auto-set)
   - **Value**: Your Supabase anon/public key
   - **Example**: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`
   - **Where to find**: Supabase Dashboard → Settings → API → Project API keys → `anon` `public`

### How to Set in Lovable

1. Go to your Lovable project: https://lovable.dev
2. Navigate to **Project Settings** → **Environment Variables**
3. Click **Add Variable** for each variable above
4. Enter the variable name and value
5. Save changes

### Verify in Code

Your frontend code should be able to access these:

```typescript
// In your Lovable frontend
const apiUrl = process.env.REACT_APP_API_URL;
const supabaseUrl = process.env.REACT_APP_SUPABASE_URL;
const supabaseKey = process.env.REACT_APP_SUPABASE_ANON_KEY;
```

---

## Summary Checklist

### GCP Secrets (Backend)
- [ ] `supabase-url` - Your Supabase project URL
- [ ] `service-jwt-secret` - Auto-generated secret for token exchange fallback
- [ ] `sumsub-api-key` - (Optional) SumSub API key
- [ ] `companies-house-api-key` - (Optional) Companies House API key

### Lovable Environment Variables (Frontend)
- [ ] `REACT_APP_API_URL` - Backend orchestration service URL
- [ ] `REACT_APP_SUPABASE_URL` - (Usually auto-set) Supabase project URL
- [ ] `REACT_APP_SUPABASE_ANON_KEY` - (Usually auto-set) Supabase anon key

---

## Quick Reference Commands

```powershell
# Set GCP project
gcloud config set project credovo-eu-apps-nonprod

# Add Supabase URL
echo -n "https://your-project.supabase.co" | gcloud secrets versions add supabase-url --data-file=-

# Generate and add Service JWT Secret
$secret = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 64 | ForEach-Object {[char]$_})
$secretBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($secret))
$secretBase64 | gcloud secrets versions add service-jwt-secret --data-file=-

# Get orchestration service URL for Lovable
cd infrastructure/terraform
terraform output orchestration_service_url
```

