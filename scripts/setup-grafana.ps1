# Setup Grafana on GCP with Cloud Monitoring integration
# This script automates the Grafana setup process

param(
    [string]$ProjectId = "credovo-eu-apps-nonprod",
    [string]$Region = "europe-west1",
    [string]$GrafanaAdminUser = "admin",
    [string]$Domain = ""
)

$ErrorActionPreference = "Stop"

Write-Host "=== Grafana Setup for Credovo Platform ===" -ForegroundColor Cyan
Write-Host ""

# Check prerequisites
Write-Host "Checking prerequisites..." -ForegroundColor Yellow

# Check if gcloud is installed
try {
    $gcloudVersion = gcloud --version 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "gcloud not found"
    }
    Write-Host "  [OK] gcloud CLI found" -ForegroundColor Green
} catch {
    Write-Host "  [FAIL] gcloud CLI not found. Please install Google Cloud SDK." -ForegroundColor Red
    exit 1
}

# Check if terraform is installed
try {
    $terraformVersion = terraform --version 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "terraform not found"
    }
    Write-Host "  [OK] Terraform found" -ForegroundColor Green
} catch {
    Write-Host "  [FAIL] Terraform not found. Please install Terraform." -ForegroundColor Red
    exit 1
}

# Set project
Write-Host ""
Write-Host "Setting GCP project..." -ForegroundColor Yellow
gcloud config set project $ProjectId
if ($LASTEXITCODE -ne 0) {
    Write-Host "  [FAIL] Failed to set project" -ForegroundColor Red
    exit 1
}
Write-Host "  [OK] Project set to $ProjectId" -ForegroundColor Green

# Enable required APIs
Write-Host ""
Write-Host "Enabling required APIs..." -ForegroundColor Yellow
$apis = @(
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "monitoring.googleapis.com",
    "cloudresourcemanager.googleapis.com"
)

foreach ($api in $apis) {
    Write-Host "  Enabling $api..." -ForegroundColor Gray
    gcloud services enable $api --project=$ProjectId 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    [OK] $api enabled" -ForegroundColor Green
    } else {
        Write-Host "    [WARN] Failed to enable $api (may already be enabled)" -ForegroundColor Yellow
    }
}

# Create service account for Grafana
Write-Host ""
Write-Host "Creating Grafana service account..." -ForegroundColor Yellow

$serviceAccountEmail = "grafana-monitoring@${ProjectId}.iam.gserviceaccount.com"

# Check if service account exists
$existingSA = gcloud iam service-accounts describe $serviceAccountEmail --project=$ProjectId 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  [OK] Service account already exists" -ForegroundColor Green
} else {
    gcloud iam service-accounts create grafana-monitoring `
        --display-name="Grafana Monitoring Service Account" `
        --description="Service account for Grafana to access Google Cloud Monitoring" `
        --project=$ProjectId
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Service account created" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Failed to create service account" -ForegroundColor Red
        exit 1
    }
}

# Grant Monitoring Viewer role to all regional projects
Write-Host ""
Write-Host "Granting Monitoring Viewer permissions..." -ForegroundColor Yellow

$regionalProjects = @(
    $ProjectId,
    "credovo-uk-apps-prod",
    "credovo-uae-apps-prod",
    "credovo-us-apps-prod",
    "credovo-eu-apps-prod"
)

foreach ($project in $regionalProjects) {
    Write-Host "  Granting permissions for $project..." -ForegroundColor Gray
    gcloud projects add-iam-policy-binding $project `
        --member="serviceAccount:$serviceAccountEmail" `
        --role="roles/monitoring.viewer" `
        --condition=None 2>&1 | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    [OK] Permissions granted for $project" -ForegroundColor Green
    } else {
        Write-Host "    [WARN] Failed to grant permissions for $project (may not have access)" -ForegroundColor Yellow
    }
}

# Create service account key
Write-Host ""
Write-Host "Creating service account key..." -ForegroundColor Yellow

$keyFile = "grafana-service-account-key.json"
if (Test-Path $keyFile) {
    Write-Host "  [INFO] Key file already exists, skipping creation" -ForegroundColor Yellow
    Write-Host "  [INFO] To regenerate, delete $keyFile and run this script again" -ForegroundColor Gray
} else {
    gcloud iam service-accounts keys create $keyFile `
        --iam-account=$serviceAccountEmail `
        --project=$ProjectId
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Service account key created: $keyFile" -ForegroundColor Green
        Write-Host "  [WARN] Keep this file secure! It will be uploaded to Secret Manager." -ForegroundColor Yellow
    } else {
        Write-Host "  [FAIL] Failed to create service account key" -ForegroundColor Red
        exit 1
    }
}

# Deploy Grafana using Terraform
Write-Host ""
Write-Host "Deploying Grafana with Terraform..." -ForegroundColor Yellow

$terraformDir = "infrastructure/terraform"
Push-Location $terraformDir

# Initialize Terraform if needed
if (-not (Test-Path ".terraform")) {
    Write-Host "  Initializing Terraform..." -ForegroundColor Gray
    terraform init
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [FAIL] Terraform initialization failed" -ForegroundColor Red
        Pop-Location
        exit 1
    }
}

# Apply Terraform configuration
Write-Host "  Applying Terraform configuration..." -ForegroundColor Gray
terraform apply -auto-approve `
    -var="project_id=$ProjectId" `
    -var="region=$Region" `
    -var="grafana_admin_user=$GrafanaAdminUser" `
    -var="domain=$Domain"

if ($LASTEXITCODE -eq 0) {
    Write-Host "  [OK] Grafana deployed successfully" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Terraform apply failed" -ForegroundColor Red
    Pop-Location
    exit 1
}

# Get Grafana URL and admin password
Write-Host ""
Write-Host "Retrieving Grafana configuration..." -ForegroundColor Yellow

$grafanaUrl = terraform output -raw grafana_url
$adminPassword = terraform output -raw grafana_admin_password 2>&1

if ($LASTEXITCODE -eq 0 -and $grafanaUrl) {
    Write-Host "  [OK] Grafana URL: $grafanaUrl" -ForegroundColor Green
    Write-Host "  [OK] Admin username: $GrafanaAdminUser" -ForegroundColor Green
    Write-Host "  [OK] Admin password: (stored in Secret Manager)" -ForegroundColor Green
    
    # Get password from Secret Manager
    $passwordSecret = terraform output -raw grafana_admin_password_secret 2>&1
    if ($passwordSecret) {
        $adminPassword = gcloud secrets versions access latest --secret=$passwordSecret --project=$ProjectId 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "=== Grafana Access Information ===" -ForegroundColor Cyan
            Write-Host "URL: $grafanaUrl" -ForegroundColor White
            Write-Host "Username: $GrafanaAdminUser" -ForegroundColor White
            Write-Host "Password: $adminPassword" -ForegroundColor White
            Write-Host ""
            Write-Host "⚠️  Save this password securely!" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "  [WARN] Could not retrieve Grafana URL from Terraform output" -ForegroundColor Yellow
}

Pop-Location

# Next steps
Write-Host ""
Write-Host "=== Next Steps ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Access Grafana at: $grafanaUrl" -ForegroundColor White
Write-Host "2. Log in with admin credentials above" -ForegroundColor White
Write-Host "3. Configure Google Cloud Monitoring data source:" -ForegroundColor White
Write-Host "   - Go to Configuration → Data Sources" -ForegroundColor Gray
Write-Host "   - Add 'Google Cloud Monitoring'" -ForegroundColor Gray
Write-Host "   - Upload service account key: $keyFile" -ForegroundColor Gray
Write-Host "4. Import dashboard:" -ForegroundColor White
Write-Host "   - Go to Dashboards → Import" -ForegroundColor Gray
Write-Host "   - Upload: infrastructure/grafana/credovo-dashboard.json" -ForegroundColor Gray
Write-Host "5. Configure project variables for all regions" -ForegroundColor White
Write-Host ""
Write-Host "For detailed instructions, see: docs/GRAFANA_SETUP.md" -ForegroundColor Gray
Write-Host ""
