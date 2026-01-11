# Quick Start Guide - Deploy to GCP

This guide will help you quickly deploy the Credovo platform to GCP.

## Prerequisites

- ✅ GCP Project: `credovo-eu-apps-nonprod` (already set up)
- ✅ Terraform state bucket: `gs://credovo-terraform-state` (already exists)
- ✅ GitHub repository: `AmanorsElliot/credovo-platform` (already connected)
- ⚠️ GCP Authentication: Need to authenticate for Terraform

## Step 1: Authenticate with GCP

```powershell
# Authenticate for Terraform (will open browser)
gcloud auth application-default login

# Verify project is set
gcloud config set project credovo-eu-apps-nonprod
```

## Step 2: Deploy Infrastructure with Terraform

```powershell
# Option A: Use the automated script (recommended)
cd scripts
.\deploy-to-gcp.ps1

# Option B: Manual deployment
cd infrastructure\terraform
terraform init
terraform plan
terraform apply
```

This will create:
- Service accounts for each microservice
- Artifact Registry repository
- Cloud Run services (not deployed yet, just infrastructure)
- Secret Manager secrets (empty placeholders)
- Pub/Sub topics
- Data Lake buckets
- VPC connector
- Monitoring dashboards

## Step 3: Configure Secrets

```powershell
cd scripts
.\configure-secrets-now.ps1
```

This will configure:
- Lovable JWKS URI
- Lovable Audience
- Service JWT Secret (auto-generated)
- SumSub API Key (you'll be prompted)
- Companies House API Key (you'll be prompted)
- The Companies API Key (you'll be prompted)
- Plaid API credentials (you'll be prompted)
- Shufti Pro API credentials (you'll be prompted)

## Step 4: Set Up Cloud Build GitHub Integration

See [Cloud Build Setup Guide](CLOUD_BUILD_GITHUB_SETUP.md) for detailed instructions.

Quick setup:
1. Go to: https://console.cloud.google.com/cloud-build/connections?project=credovo-eu-apps-nonprod
2. Complete OAuth authorization for your GitHub repository
3. Create Cloud Build trigger (parallel build for all services):
   ```powershell
   .\scripts\setup-parallel-build-trigger.ps1
   ```

## Step 5: Deploy Services

### Option A: Using Cloud Build (Recommended - Automatic)

1. Push to `main` branch
2. Cloud Build automatically:
   - Builds Docker images
   - Pushes to Artifact Registry
   - Deploys to Cloud Run

View builds: https://console.cloud.google.com/cloud-build/builds?project=credovo-eu-apps-nonprod

### Option B: Manual Deployment

```powershell
# Deploy connector service
cd services\connector-service
gcloud builds submit --config cloudbuild.yaml

# Deploy KYC/KYB service
cd ..\kyc-kyb-service
gcloud builds submit --config cloudbuild.yaml

# Deploy orchestration service
cd ..\orchestration-service
gcloud builds submit --config cloudbuild.yaml
```

## Step 6: Verify Deployment

```powershell
# Get service URLs
cd infrastructure\terraform
terraform output

# Test health endpoints
$urls = terraform output -json | ConvertFrom-Json
curl $urls.connector_service_url.value/health
curl $urls.kyc_kyb_service_url.value/health
curl $urls.orchestration_service_url.value/health
curl $urls.company_search_service_url.value/health
curl $urls.open_banking_service_url.value/health
```

## Troubleshooting

### Terraform Authentication Error
```powershell
gcloud auth application-default login
```

### Cloud Build Failures
- Verify Cloud Build connection is authorized
- Check Cloud Build triggers are created
- Ensure service account has correct permissions
- View build logs in Cloud Build console

### Service Deployment Issues
```powershell
# View logs
gcloud logging read "resource.type=cloud_run_revision" --limit 50

# Check service status
gcloud run services list --region=europe-west1
```

## Next Steps

1. Configure Lovable frontend with API URL from Terraform outputs
2. Test end-to-end KYC/KYB flow
3. Set up monitoring alerts
4. Configure custom domain (optional)

For detailed information, see:
- [Deployment Guide](deployment.md)
- [Next Steps](NEXT_STEPS.md)
- [Terraform Setup](TERRAFORM_SETUP.md)

