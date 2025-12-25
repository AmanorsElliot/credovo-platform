# Infrastructure as Code

This directory contains Terraform configurations for deploying Credovo infrastructure on Google Cloud Platform.

## Prerequisites

1. GCP Project created
2. Terraform >= 1.5.0 installed
3. gcloud CLI configured
4. Service account with necessary permissions

## Setup

1. Copy `terraform.tfvars.example` to `terraform.tfvars`:
   ```bash
   cp terraform/terraform.tfvars.example terraform/terraform.tfvars
   ```

2. Edit `terraform.tfvars` with your GCP project details

3. Initialize Terraform:
   ```bash
   cd terraform
   terraform init
   ```

4. Plan the deployment:
   ```bash
   terraform plan
   ```

5. Apply the configuration:
   ```bash
   terraform apply
   ```

## Secrets

After deploying, you'll need to add secrets to Secret Manager:

```bash
# Lovable JWKS URI
echo -n "https://auth.lovable.dev/.well-known/jwks.json" | gcloud secrets create lovable-jwks-uri --data-file=-

# Lovable Audience
echo -n "credovo-api" | gcloud secrets create lovable-audience --data-file=-

# Service JWT Secret (generate a secure random string)
openssl rand -base64 32 | gcloud secrets create service-jwt-secret --data-file=-

# SumSub API Key
echo -n "your-sumsub-api-key" | gcloud secrets create sumsub-api-key --data-file=-

# Companies House API Key
echo -n "your-companies-house-api-key" | gcloud secrets create companies-house-api-key --data-file=-
```

## Structure

- `main.tf` - Main configuration, APIs, service accounts
- `cloud-run.tf` - Cloud Run service definitions
- `data-lake.tf` - GCS buckets and BigQuery setup
- `networking.tf` - Pub/Sub, Cloud Tasks, Secret Manager
- `monitoring.tf` - Cloud Monitoring dashboards and alerts
- `variables.tf` - Variable definitions
- `outputs.tf` - Output values

