# PowerShell script to deploy Credovo Platform to GCP
# Run this script after setting up GitHub secrets

param(
    [string]$ProjectId = "credovo-platform-dev",
    [string]$Region = "europe-west1"
)

Write-Host "=== Credovo Platform GCP Deployment ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Verify GCP authentication
Write-Host "Step 1: Verifying GCP authentication..." -ForegroundColor Yellow
$currentProject = gcloud config get-value project 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: gcloud CLI not configured. Please install and configure gcloud CLI first." -ForegroundColor Red
    exit 1
}

Write-Host "Current project: $currentProject" -ForegroundColor Green
Write-Host "Setting project to: $ProjectId" -ForegroundColor Yellow
gcloud config set project $ProjectId

# Step 2: Authenticate for Terraform
Write-Host ""
Write-Host "Step 2: Setting up application default credentials..." -ForegroundColor Yellow
Write-Host "This will open a browser for authentication." -ForegroundColor Cyan
gcloud auth application-default login

# Step 3: Verify Terraform state bucket
Write-Host ""
Write-Host "Step 3: Verifying Terraform state bucket..." -ForegroundColor Yellow
$bucketExists = gsutil ls -b "gs://credovo-terraform-state" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Creating Terraform state bucket..." -ForegroundColor Yellow
    gsutil mb -p $ProjectId -l $Region "gs://credovo-terraform-state"
    gsutil versioning set on "gs://credovo-terraform-state"
    Write-Host "Terraform state bucket created." -ForegroundColor Green
} else {
    Write-Host "Terraform state bucket exists." -ForegroundColor Green
}

# Step 4: Initialize Terraform
Write-Host ""
Write-Host "Step 4: Initializing Terraform..." -ForegroundColor Yellow
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptPath
$terraformDir = Join-Path $repoRoot "infrastructure\terraform"
Set-Location $terraformDir
terraform init

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Terraform initialization failed." -ForegroundColor Red
    exit 1
}

# Step 5: Terraform plan
Write-Host ""
Write-Host "Step 5: Running Terraform plan..." -ForegroundColor Yellow
terraform plan -out=tfplan

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Terraform plan failed." -ForegroundColor Red
    exit 1
}

# Step 6: Confirm before apply
Write-Host ""
$confirm = Read-Host "Review the plan above. Do you want to apply these changes? (yes/no)"
if ($confirm -ne "yes") {
    Write-Host "Deployment cancelled." -ForegroundColor Yellow
    exit 0
}

# Step 7: Terraform apply
Write-Host ""
Write-Host "Step 7: Applying Terraform configuration..." -ForegroundColor Yellow
terraform apply tfplan

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Terraform apply failed." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== Infrastructure deployed successfully! ===" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Configure secrets in GCP Secret Manager (see docs/deployment.md)"
Write-Host "2. Set up GitHub Actions secrets (see docs/NEXT_STEPS.md)"
Write-Host "3. Deploy services using GitHub Actions or manually"
Write-Host ""
Write-Host "To view outputs:" -ForegroundColor Cyan
Write-Host "  terraform output" -ForegroundColor White

# Return to original directory
Set-Location $repoRoot

