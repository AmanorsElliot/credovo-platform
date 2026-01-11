# Deploy Proxy Service using Cloud Build
# This script uses Cloud Build to build and deploy the proxy service

param(
    [string]$ProjectId = "credovo-eu-apps-nonprod",
    [string]$Region = "europe-west1"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deploying Proxy Service via Cloud Build" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$ErrorActionPreference = "Stop"

# Step 1: Create Service Account (if it doesn't exist)
Write-Host "Step 1: Checking service account..." -ForegroundColor Yellow
try {
    gcloud iam service-accounts describe proxy-service@$ProjectId.iam.gserviceaccount.com `
        --project=$ProjectId 2>&1 | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Service account already exists" -ForegroundColor Green
    }
} catch {
    Write-Host "  Creating service account..." -ForegroundColor Gray
    gcloud iam service-accounts create proxy-service `
        --display-name="Proxy Service Account" `
        --description="Service account for proxy service to call orchestration service" `
        --project=$ProjectId
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Service account created" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Failed to create service account" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""

# Step 2: Submit Cloud Build
Write-Host "Step 2: Submitting Cloud Build..." -ForegroundColor Yellow
try {
    Write-Host "  Building and deploying proxy service..." -ForegroundColor Gray
    
    gcloud builds submit `
        --config=services/proxy-service/cloudbuild.yaml `
        --project=$ProjectId `
        --region=$Region `
        --substitutions=_REGION=$Region,_ARTIFACT_REGISTRY=credovo-services
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Build and deployment completed successfully" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Build/deployment failed" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "  ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 3: Grant Service Account Access to Orchestration Service
Write-Host "Step 3: Granting service account access..." -ForegroundColor Yellow
try {
    Write-Host "  Granting proxy service account access to orchestration service..." -ForegroundColor Gray
    
    gcloud run services add-iam-policy-binding orchestration-service `
        --region=$Region `
        --member="serviceAccount:proxy-service@$ProjectId.iam.gserviceaccount.com" `
        --role=roles/run.invoker `
        --project=$ProjectId
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Service account permissions granted" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  Failed to grant permissions (may already be set)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ⚠️  Error granting permissions: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""

# Step 4: Get Service URL and Test
Write-Host "Step 4: Testing deployment..." -ForegroundColor Yellow
try {
    $serviceUrl = (gcloud run services describe proxy-service `
        --region=$Region `
        --project=$ProjectId `
        --format="value(status.url)")
    
    Write-Host "  Service URL: $serviceUrl" -ForegroundColor Cyan
    Write-Host "  Testing health endpoint..." -ForegroundColor Gray
    
    Start-Sleep -Seconds 5  # Wait for service to be ready
    
    $healthResponse = Invoke-RestMethod -Uri "$serviceUrl/health" -TimeoutSec 10
    
    if ($healthResponse.status -eq "healthy") {
        Write-Host "  ✅ Health check passed" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  Health check returned unexpected response" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ⚠️  Health check failed: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "     Service may still be starting up. Try again in a moment." -ForegroundColor Gray
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Update your Edge Function to use PROXY_SERVICE_URL: $serviceUrl" -ForegroundColor White
Write-Host "2. Set environment variable in Supabase: PROXY_SERVICE_URL=$serviceUrl" -ForegroundColor White
Write-Host "3. Test the end-to-end flow" -ForegroundColor White
Write-Host ""
Write-Host "Proxy Service URL: $serviceUrl" -ForegroundColor Cyan
