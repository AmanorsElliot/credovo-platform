# Deploy all services to Cloud Run using Cloud Build
# This script builds and deploys all services in the correct region

param(
    [string]$ProjectId = "credovo-eu-apps-nonprod",
    [string]$Region = "europe-west1"
)

$ErrorActionPreference = "Stop"

Write-Host "=== Deploying All Services to Cloud Run ===" -ForegroundColor Cyan
Write-Host "Project: $ProjectId" -ForegroundColor Gray
Write-Host "Region: $Region" -ForegroundColor Gray
Write-Host ""

# Set GCP project
gcloud config set project $ProjectId

$services = @(
    "orchestration-service",
    "kyc-kyb-service",
    "connector-service"
)

foreach ($service in $services) {
    Write-Host "--- Deploying $service ---" -ForegroundColor Yellow
    
    $cloudbuildYaml = "services/$service/cloudbuild.yaml"
    
    if (-not (Test-Path $cloudbuildYaml)) {
        Write-Host "Error: $cloudbuildYaml not found" -ForegroundColor Red
        continue
    }
    
    Write-Host "Submitting Cloud Build job for $service..." -ForegroundColor Cyan
    
    # Use Cloud Build API with explicit region
    # Note: Cloud Build jobs run in a specific region, but we need to ensure
    # the build happens in a region that's allowed by org policy
    try {
        # Try to submit with explicit region
        $buildResult = gcloud builds submit `
            --config=$cloudbuildYaml `
            --region=$Region `
            --project=$ProjectId `
            2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "$service deployed successfully!" -ForegroundColor Green
        } else {
            Write-Host "Error deploying $service:" -ForegroundColor Red
            Write-Host $buildResult -ForegroundColor Red
        }
    } catch {
        Write-Host "Error: $_" -ForegroundColor Red
    }
    
    Write-Host ""
}

Write-Host "=== Deployment Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Service URLs:" -ForegroundColor Yellow
foreach ($service in $services) {
    $url = gcloud run services describe $service --region=$Region --project=$ProjectId --format="value(status.url)" 2>&1
    if ($url) {
        Write-Host "$service : $url" -ForegroundColor Green
    }
}

