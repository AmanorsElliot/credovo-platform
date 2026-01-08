# Deployment Complete - Next Steps

## ✅ Completed Tasks

1. **✅ Secrets Configured**
   - Service JWT Secret: Generated and added
   - Lovable JWKS URI: Configured
   - Lovable Audience: Configured
   - ⚠️ **Supabase URL**: Still needs to be added (see below)

2. **✅ VPC Connector**
   - Imported back into Terraform state
   - Note: Currently in ERROR state but services work without it
   - Can be fixed later with proper permissions

3. **✅ Infrastructure Deployed**
   - All Cloud Run services created
   - Service accounts configured
   - Monitoring and logging set up

## 🔧 Remaining Tasks

### 1. Add Supabase URL to Secret Manager

**REQUIRED** - Add your Supabase project URL:

```powershell
# Replace with your actual Supabase project URL
# Get this from: Supabase Dashboard → Settings → API → Project URL
$supabaseUrl = "https://your-project-id.supabase.co"
$supabaseUrl | gcloud secrets versions add supabase-url --data-file=- --project=credovo-eu-apps-nonprod
```

### 2. Deploy Service Code to Cloud Run

You have two options:

#### Option A: Use Cloud Build (Recommended)

The services have `cloudbuild.yaml` files configured. You can trigger builds via:

```powershell
# For orchestration service
gcloud builds submit --config=services/orchestration-service/cloudbuild.yaml --project=credovo-eu-apps-nonprod

# For KYC/KYB service
gcloud builds submit --config=services/kyc-kyb-service/cloudbuild.yaml --project=credovo-eu-apps-nonprod

# For connector service
gcloud builds submit --config=services/connector-service/cloudbuild.yaml --project=credovo-eu-apps-nonprod
```

#### Option B: Build and Deploy Locally

Use the deployment script:

```powershell
cd scripts
.\deploy-services.ps1
```

**Note**: Local Docker builds require Docker Desktop and may be complex due to shared package dependencies. Cloud Build is recommended.

#### Option C: Use GitHub Actions

If you've configured GitHub Actions with the required secrets:
- Push to `main` or `develop` branch
- The workflow will automatically build and deploy

### 3. Configure Lovable Frontend

Add these environment variables in your Lovable project settings:

#### Required Variables

1. **`REACT_APP_API_URL`**
   - **Value**: `https://orchestration-service-saz24fo3sa-ew.a.run.app`
   - **How to get updated URL**: 
     ```powershell
     cd infrastructure/terraform
     terraform output orchestration_service_url
     ```

#### Supabase Variables (Usually Auto-configured)

If Lovable doesn't automatically set these when you configure Supabase:

2. **`REACT_APP_SUPABASE_URL`** (if not auto-set)
   - **Value**: Your Supabase project URL
   - **Example**: `https://your-project-id.supabase.co`
   - **Where to find**: Supabase Dashboard → Settings → API → Project URL

3. **`REACT_APP_SUPABASE_ANON_KEY`** (if not auto-set)
   - **Value**: Your Supabase anon/public key
   - **Where to find**: Supabase Dashboard → Settings → API → Project API keys → `anon` `public`

#### How to Set in Lovable

1. Go to your Lovable project: https://lovable.dev
2. Navigate to **Project Settings** → **Environment Variables**
3. Click **Add Variable** for each variable above
4. Enter the variable name and value
5. Save changes

## 📋 Service URLs

Get the latest URLs:

```powershell
cd infrastructure/terraform
terraform output
```

Current URLs:
- **Orchestration Service**: `https://orchestration-service-saz24fo3sa-ew.a.run.app`
- **KYC/KYB Service**: `https://kyc-kyb-service-saz24fo3sa-ew.a.run.app`
- **Connector Service**: `https://connector-service-saz24fo3sa-ew.a.run.app`

## 🔍 Verify Deployment

### Check Service Status

```powershell
gcloud run services list --region=europe-west1 --project=credovo-eu-apps-nonprod
```

### Test Orchestration Service

```powershell
# Health check
curl https://orchestration-service-saz24fo3sa-ew.a.run.app/health

# Should return: {"status":"ok"}
```

### Check Secrets

```powershell
# List all secrets
gcloud secrets list --project=credovo-eu-apps-nonprod

# Verify Supabase URL (if added)
gcloud secrets versions access latest --secret=supabase-url --project=credovo-eu-apps-nonprod
```

## 🐛 Troubleshooting

### Services Not Deployed Yet

If services show "Hello World" or 404:
- The Docker images haven't been deployed yet
- Use Cloud Build or the deployment script above

### VPC Connector Error

The VPC connector is in ERROR state but services work without it. To fix:
1. Delete the connector (requires additional permissions)
2. Recreate via Terraform

### Secret Access Issues

If services can't access secrets:
- Verify service accounts have `roles/secretmanager.secretAccessor`
- Check that secrets have values (not just placeholders)

## 📝 Summary Checklist

- [x] Infrastructure deployed
- [x] Service accounts created
- [x] Secrets configured (except Supabase URL)
- [ ] **Add Supabase URL to Secret Manager** ⚠️ REQUIRED
- [ ] **Deploy service code to Cloud Run** ⚠️ REQUIRED
- [ ] **Configure Lovable frontend environment variables** ⚠️ REQUIRED
- [ ] Test end-to-end flow
- [ ] Fix VPC connector (optional, can be done later)

## 🚀 Quick Start Commands

```powershell
# 1. Add Supabase URL
$supabaseUrl = "https://your-project-id.supabase.co"
$supabaseUrl | gcloud secrets versions add supabase-url --data-file=- --project=credovo-eu-apps-nonprod

# 2. Deploy services (using Cloud Build)
gcloud builds submit --config=services/orchestration-service/cloudbuild.yaml --project=credovo-eu-apps-nonprod

# 3. Get service URLs
cd infrastructure/terraform
terraform output orchestration_service_url

# 4. Configure in Lovable
# Go to Lovable → Project Settings → Environment Variables
# Add: REACT_APP_API_URL = <orchestration_service_url>
```

