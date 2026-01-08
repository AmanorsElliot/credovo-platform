# Deployment Ready! 🚀

## What's Been Set Up

✅ **GitHub Actions Workflow** - Automatic deployment on push to `main`
✅ **Deployment Scripts** - Manual deployment options
✅ **Infrastructure** - All Cloud Run services configured
✅ **Secrets** - Supabase URL and other secrets configured
✅ **Code** - All services ready to deploy

## Next Steps to Enable Automatic Deployment

### 1. Set Up Workload Identity Federation (Required)

GitHub Actions needs to authenticate to GCP. You have two options:

#### Option A: Use Existing Workload Identity (If Already Set Up)

If you already have Workload Identity set up, just add these GitHub secrets:

1. Go to: https://github.com/AmanorsElliot/credovo-platform/settings/secrets/actions
2. Add:
   - **`GCP_WIF_PROVIDER`**: Your Workload Identity provider path
     - Format: `projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/POOL_ID/providers/PROVIDER_ID`
   - **`GCP_WIF_SERVICE_ACCOUNT`**: Service account email
     - Format: `github-actions@credovo-eu-apps-nonprod.iam.gserviceaccount.com`

#### Option B: Set Up Workload Identity (If Not Set Up)

See `docs/WORKLOAD_IDENTITY_SETUP.md` for detailed instructions.

Quick setup:
```powershell
# 1. Create service account (if not exists)
gcloud iam service-accounts create github-actions \
  --display-name="GitHub Actions Service Account" \
  --project=credovo-eu-apps-nonprod

# 2. Grant necessary permissions
gcloud projects add-iam-policy-binding credovo-eu-apps-nonprod \
  --member="serviceAccount:github-actions@credovo-eu-apps-nonprod.iam.gserviceaccount.com" \
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding credovo-eu-apps-nonprod \
  --member="serviceAccount:github-actions@credovo-eu-apps-nonprod.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.writer"

# 3. Create Workload Identity Pool (via Console or API)
# See docs/WORKLOAD_IDENTITY_SETUP.md for details
```

### 2. Test the Workflow

Once secrets are configured:

1. Make a small change to any service
2. Push to `main` branch
3. Check GitHub Actions: https://github.com/AmanorsElliot/credovo-platform/actions
4. Watch the deployment happen automatically!

## Manual Deployment (If Needed)

If you need to deploy manually before setting up GitHub Actions:

### Option 1: Use Cloud Build (If Region Allows)

```powershell
gcloud builds submit --config=services/orchestration-service/cloudbuild.yaml --region=europe-west1 --project=credovo-eu-apps-nonprod
```

### Option 2: Use Deployment Script (Requires Docker)

```powershell
.\scripts\deploy-service-direct.ps1 -ServiceName orchestration-service
```

## Current Service Status

- **Orchestration Service**: Using placeholder image (`gcr.io/cloudrun/hello`)
- **KYC/KYB Service**: Using placeholder image
- **Connector Service**: Using placeholder image

**Note**: Services are deployed but using placeholder images. Once you push to GitHub with Workload Identity configured, the real code will be deployed automatically!

## What Happens on Push

1. GitHub Actions triggers on push to `main`
2. Builds Docker images for each service
3. Pushes images to Artifact Registry
4. Deploys to Cloud Run with all environment variables from Secret Manager
5. Services are live with real code!

## Verification

After deployment, verify services:

```powershell
# Check service URLs
gcloud run services list --region=europe-west1 --project=credovo-eu-apps-nonprod

# Test health endpoint
Invoke-WebRequest -Uri "https://orchestration-service-saz24fo3sa-ew.a.run.app/health"
```

## Summary

✅ **Code**: Ready
✅ **Infrastructure**: Ready
✅ **Secrets**: Configured
✅ **GitHub Actions**: Configured (needs Workload Identity secrets)
⏳ **Next**: Set up Workload Identity and add GitHub secrets, then push to deploy!

