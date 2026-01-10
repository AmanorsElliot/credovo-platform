# Deployment Guide

## Prerequisites

1. GCP Project created
2. GitHub repository set up
3. Terraform >= 1.5.0
4. gcloud CLI configured

## Step 1: GCP Project Setup

```bash
# Set your project ID
export PROJECT_ID="your-gcp-project-id"
export REGION="europe-west1"

# Create GCP project (if not exists)
gcloud projects create $PROJECT_ID

# Set as default project
gcloud config set project $PROJECT_ID

# Enable billing (required)
# gcloud billing projects link $PROJECT_ID --billing-account=BILLING_ACCOUNT_ID
```

## Step 2: Terraform State Bucket

```bash
# Create bucket for Terraform state
gsutil mb -p $PROJECT_ID -l $REGION gs://credovo-terraform-state
```

## Step 3: Deploy Infrastructure

### Option 1: Using PowerShell Script (Windows - Recommended)

```powershell
cd scripts
.\deploy-to-gcp.ps1
```

### Option 2: Manual Deployment

```bash
cd infrastructure/terraform

# Copy and edit variables (already done if terraform.tfvars exists)
# cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your project details

# Authenticate (if not already done)
gcloud auth application-default login

# Initialize Terraform
terraform init

# Plan deployment
terraform plan

# Apply
terraform apply
```

## Step 4: Configure Secrets

### Option 1: Using PowerShell Script (Windows - Recommended)

```powershell
cd scripts
.\configure-secrets-now.ps1
```

### Option 2: Manual Configuration (Linux/Mac)

```bash
# Lovable JWKS URI
echo -n "https://auth.lovable.dev/.well-known/jwks.json" | \
  gcloud secrets versions add lovable-jwks-uri --data-file=-

# Lovable Audience
echo -n "credovo-api" | \
  gcloud secrets versions add lovable-audience --data-file=-

# Service JWT Secret
openssl rand -base64 32 | \
  gcloud secrets versions add service-jwt-secret --data-file=-

# SumSub API Key
echo -n "your-sumsub-api-key" | \
  gcloud secrets versions add sumsub-api-key --data-file=-

# Companies House API Key
echo -n "your-companies-house-api-key" | \
  gcloud secrets versions add companies-house-api-key --data-file=-
```

**Note**: If secrets don't exist yet, Terraform will create them. Use `gcloud secrets versions add` to add values to existing secrets.

## Step 5: Set Up CI/CD with Cloud Build

The platform uses **Cloud Build GitHub Integration** for automatic deployments.

### Option 1: Cloud Build (Recommended - Current Setup)

1. **Connect GitHub Repository**:
   - Go to: https://console.cloud.google.com/cloud-build/connections?project=credovo-eu-apps-nonprod
   - Complete OAuth authorization for your GitHub repository

2. **Create Cloud Build Triggers**:
   - Go to: https://console.cloud.google.com/cloud-build/triggers?project=credovo-eu-apps-nonprod
   - Create triggers for each service (or use the script):
   ```powershell
   .\scripts\setup-cloud-build-triggers.ps1
   ```

3. **Automatic Deployment**:
   - Push to `main` branch triggers automatic builds
   - Services are built, pushed to Artifact Registry, and deployed to Cloud Run

See [Cloud Build Setup Guide](CLOUD_BUILD_GITHUB_SETUP.md) for detailed instructions.

### Option 2: Manual Deployment

```bash
# Build and push connector service
cd services/connector-service
gcloud builds submit --config cloudbuild.yaml

# Build and push KYC service
cd ../kyc-kyb-service
gcloud builds submit --config cloudbuild.yaml

# Build and push orchestration service
cd ../orchestration-service
gcloud builds submit --config cloudbuild.yaml
```

## Step 6: Configure Lovable Frontend

1. Create Lovable project
2. Connect GitHub repository
3. Configure environment variables:
   - `REACT_APP_API_URL`: Get from Terraform output `orchestration_service_url`
   - `REACT_APP_LOVABLE_AUTH_URL`: Lovable Cloud auth URL

## Step 7: Verify Deployment

```bash
# Get service URLs
terraform output

# Test health endpoints
curl https://kyc-kyb-service-xxx.run.app/health
curl https://connector-service-xxx.run.app/health
curl https://orchestration-service-xxx.run.app/health
```

## Monitoring

- View logs: `gcloud logging read "resource.type=cloud_run_revision"`
- View metrics: GCP Console > Cloud Monitoring
- View service status: GCP Console > Cloud Run

