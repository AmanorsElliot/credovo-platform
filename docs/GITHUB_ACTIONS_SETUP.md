# GitHub Actions Setup for Automatic Deployment

## Overview

GitHub Actions automatically builds and deploys services to Cloud Run when you push to the `main` branch.

## Required GitHub Secrets

You need to configure these secrets in your GitHub repository:

1. Go to: **Settings** → **Secrets and variables** → **Actions**

2. Add these secrets:

### Required Secrets

- **`GCP_WIF_PROVIDER`**: Workload Identity Federation provider
  - Format: `projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/POOL_ID/providers/PROVIDER_ID`
  - Example: `projects/123456789/locations/global/workloadIdentityPools/github-actions/providers/github`

- **`GCP_WIF_SERVICE_ACCOUNT`**: Service account email for Workload Identity
  - Format: `SERVICE_ACCOUNT@PROJECT_ID.iam.gserviceaccount.com`
  - Example: `github-actions@credovo-eu-apps-nonprod.iam.gserviceaccount.com`

## How It Works

1. **Trigger**: Push to `main` branch (or changes to `services/**` or `shared/**`)
2. **Build**: GitHub Actions builds Docker images for each service
3. **Push**: Images are pushed to Artifact Registry
4. **Deploy**: Services are deployed to Cloud Run with all environment variables from Secret Manager

## Workflow File

The workflow is defined in `.github/workflows/deploy.yml`

## Manual Deployment

If you need to deploy manually without pushing to GitHub:

```powershell
# Deploy a specific service
.\scripts\deploy-service-direct.ps1 -ServiceName orchestration-service

# Or use Cloud Build (if region constraints allow)
gcloud builds submit --config=services/orchestration-service/cloudbuild.yaml --region=europe-west1 --project=credovo-eu-apps-nonprod
```

## Troubleshooting

### Workload Identity Not Set Up

If you see authentication errors, you need to set up Workload Identity Federation:

1. Check if the workload identity pool exists:
   ```powershell
   gcloud iam workload-identity-pools list --location=global --project=credovo-eu-apps-nonprod
   ```

2. If it doesn't exist, create it (see `docs/WORKLOAD_IDENTITY_SETUP.md`)

### Region Constraint Errors

If Cloud Build fails with region constraint errors, the GitHub Actions workflow uses Docker directly instead of Cloud Build, which avoids this issue.

### Missing Environment Variables

Environment variables are automatically loaded from Secret Manager via Terraform configuration. If variables are missing:

1. Check Secret Manager:
   ```powershell
   gcloud secrets list --project=credovo-eu-apps-nonprod
   ```

2. Verify secrets have values:
   ```powershell
   gcloud secrets versions access latest --secret=supabase-url --project=credovo-eu-apps-nonprod
   ```

## Next Steps

1. Set up Workload Identity Federation (if not already done)
2. Add GitHub secrets (`GCP_WIF_PROVIDER`, `GCP_WIF_SERVICE_ACCOUNT`)
3. Push to `main` branch - deployment will happen automatically!

