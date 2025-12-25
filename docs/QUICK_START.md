# Quick Start Guide - Deploy to GCP

This guide will help you quickly deploy the Credovo platform to GCP.

## Prerequisites

- ✅ GCP Project: `credovo-platform-dev` (already set up)
- ✅ Terraform state bucket: `gs://credovo-terraform-state` (already exists)
- ✅ GitHub repository: `AmanorsElliot/credovo-platform` (already connected)
- ⚠️ GCP Authentication: Need to authenticate for Terraform

## Step 1: Authenticate with GCP

```powershell
# Authenticate for Terraform (will open browser)
gcloud auth application-default login

# Verify project is set
gcloud config set project credovo-platform-dev
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
.\configure-secrets.ps1
```

This will configure:
- Lovable JWKS URI
- Lovable Audience
- Service JWT Secret (auto-generated)
- SumSub API Key (you'll be prompted)
- Companies House API Key (you'll be prompted)

## Step 4: Set Up GitHub Actions

```powershell
cd scripts
.\setup-github-secrets.ps1
```

This will:
1. Create a service account for GitHub Actions
2. Grant necessary permissions
3. Generate a service account key
4. Display instructions for adding GitHub secrets

Then go to: https://github.com/AmanorsElliot/credovo-platform/settings/secrets/actions

Add these secrets:
- `GCP_PROJECT_ID`: `credovo-platform-dev`
- `GCP_SA_KEY`: (JSON from the script output)
- `ARTIFACT_REGISTRY`: `credovo-services`

## Step 5: Deploy Services

### Option A: Using GitHub Actions (Recommended)

1. Push to main branch or manually trigger workflow
2. Go to: https://github.com/AmanorsElliot/credovo-platform/actions
3. Select "Deploy Services to GCP" workflow
4. Click "Run workflow"

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
```

## Troubleshooting

### Terraform Authentication Error
```powershell
gcloud auth application-default login
```

### GitHub Actions Failures
- Verify all secrets are set in GitHub
- Check service account has correct permissions
- Ensure Artifact Registry repository exists

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

