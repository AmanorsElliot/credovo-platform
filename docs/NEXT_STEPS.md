# Next Steps After GitHub Push

## Step 1: Set Up GCP Project

### 1.1 Create GCP Project
```bash
# Set your project ID (choose a unique name)
export PROJECT_ID="credovo-platform-$(date +%s)"
export REGION="europe-west1"

# Create the project
gcloud projects create $PROJECT_ID

# Set as default
gcloud config set project $PROJECT_ID

# Enable billing (REQUIRED - you'll need a billing account)
# gcloud billing projects link $PROJECT_ID --billing-account=YOUR_BILLING_ACCOUNT_ID
```

### 1.2 Create Terraform State Bucket
```bash
# Create bucket for Terraform state
gsutil mb -p $PROJECT_ID -l $REGION gs://credovo-terraform-state

# Enable versioning on the bucket
gsutil versioning set on gs://credovo-terraform-state
```

## Step 2: Configure Terraform

### 2.1 Set Up Terraform Variables
```bash
cd infrastructure/terraform

# Copy the example file
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your project details
# You can use: notepad terraform.tfvars (Windows) or your preferred editor
```

Edit `terraform.tfvars`:
```hcl
project_id   = "your-gcp-project-id"
region       = "europe-west1"
zone         = "europe-west1-b"
environment  = "staging"
min_instances = 0
max_instances = 10
```

### 2.2 Initialize and Deploy Infrastructure
```bash
# Initialize Terraform
terraform init

# Review what will be created
terraform plan

# Deploy infrastructure (this will take several minutes)
terraform apply
```

**Note**: The first `terraform apply` will:
- Enable all required GCP APIs
- Create service accounts
- Set up data lake buckets
- Create Pub/Sub topics
- Set up Secret Manager secrets (empty placeholders)
- Create VPC connector
- Set up monitoring dashboards

## Step 3: Configure Secrets

After Terraform creates the secret placeholders, add the actual secret values:

```bash
# Lovable JWKS URI (update with actual Lovable Cloud endpoint)
echo -n "https://auth.lovable.dev/.well-known/jwks.json" | \
  gcloud secrets versions add lovable-jwks-uri --data-file=-

# Lovable Audience
echo -n "credovo-api" | \
  gcloud secrets versions add lovable-audience --data-file=-

# Service JWT Secret (generate a secure random string)
openssl rand -base64 32 | \
  gcloud secrets versions add service-jwt-secret --data-file=-

# SumSub API Key (get from SumSub dashboard)
echo -n "your-actual-sumsub-api-key" | \
  gcloud secrets versions add sumsub-api-key --data-file=-

# Companies House API Key (get from Companies House)
echo -n "your-actual-companies-house-api-key" | \
  gcloud secrets versions add companies-house-api-key --data-file=-
```

## Step 4: Configure GitHub Actions

### 4.1 Create Service Account for GitHub Actions
```bash
# Create service account
gcloud iam service-accounts create github-actions \
    --display-name="GitHub Actions Service Account"

# Grant necessary permissions
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:github-actions@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/run.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:github-actions@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/artifactregistry.writer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:github-actions@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/iam.serviceAccountUser"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:github-actions@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/cloudbuild.builds.editor"
```

### 4.2 Create and Download Service Account Key
```bash
# Create key
gcloud iam service-accounts keys create github-actions-key.json \
    --iam-account=github-actions@$PROJECT_ID.iam.gserviceaccount.com

# Display the key (copy this entire JSON output)
cat github-actions-key.json

# Delete local key file for security
rm github-actions-key.json
```

### 4.3 Add GitHub Secrets
Go to your GitHub repository → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

Add these secrets:

1. **GCP_PROJECT_ID**
   - Value: Your GCP project ID (e.g., `credovo-platform-1234567890`)

2. **GCP_SA_KEY**
   - Value: The entire JSON content from `github-actions-key.json` (the output from `cat` command above)

3. **ARTIFACT_REGISTRY**
   - Value: `credovo-services`

## Step 5: Test Deployment

### 5.1 Trigger GitHub Actions
```bash
# Make a small change and push to trigger deployment
# Or manually trigger from GitHub Actions tab
```

The GitHub Actions workflow will:
- Build Docker images
- Push to Artifact Registry
- Deploy to Cloud Run

### 5.2 Verify Services Are Running
```bash
# Get service URLs from Terraform
cd infrastructure/terraform
terraform output

# Test health endpoints
curl https://kyc-kyb-service-xxx.run.app/health
curl https://connector-service-xxx.run.app/health
curl https://orchestration-service-xxx.run.app/health
```

## Step 6: Set Up Lovable Frontend

1. Go to https://lovable.dev
2. Create a new project
3. Connect your GitHub repository (`credovo-platform`)
4. Configure environment variables:
   - `REACT_APP_API_URL`: Get from `terraform output orchestration_service_url`
   - `REACT_APP_LOVABLE_AUTH_URL`: Your Lovable Cloud auth URL
5. Configure Lovable Cloud authentication settings

## Step 7: Test End-to-End Flow

1. Access your Lovable frontend
2. Authenticate with Lovable Cloud
3. Test KYC initiation:
   ```bash
   curl -X POST https://orchestration-service-xxx.run.app/api/v1/applications/test-123/kyc/initiate \
     -H "Authorization: Bearer YOUR_LOVABLE_JWT_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{
       "type": "individual",
       "data": {
         "firstName": "Test",
         "lastName": "User",
         "dateOfBirth": "1990-01-01"
       }
     }'
   ```

## Troubleshooting

### Terraform Errors
- Ensure billing is enabled on the project
- Check that all required APIs are enabled
- Verify service account has necessary permissions

### GitHub Actions Failures
- Verify all secrets are set correctly
- Check that Artifact Registry repository exists
- Ensure service account has correct IAM roles

### Service Deployment Issues
- Check Cloud Run logs: `gcloud logging read "resource.type=cloud_run_revision"`
- Verify secrets are accessible: `gcloud secrets versions access latest --secret=service-jwt-secret`
- Check service account permissions

## Useful Commands

```bash
# View all Cloud Run services
gcloud run services list

# View logs for a service
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=kyc-kyb-service" --limit 50

# Get service URL
gcloud run services describe kyc-kyb-service --region=europe-west1 --format="value(status.url)"

# View Terraform outputs
cd infrastructure/terraform && terraform output
```

