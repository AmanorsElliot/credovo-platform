# Deploy Proxy Service to Cloud Run
# This script deploys the proxy service that bridges Edge Functions to the orchestration service

param(
    [string]$ProjectId = "credovo-eu-apps-nonprod",
    [string]$Region = "europe-west1",
    [string]$OrchestrationServiceUrl = "https://orchestration-service-saz24fo3sa-ew.a.run.app"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deploying Proxy Service" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$ErrorActionPreference = "Stop"

# Step 1: Create Service Account
Write-Host "Step 1: Creating service account..." -ForegroundColor Yellow
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

# Step 2: Build Docker Image
Write-Host "Step 2: Building Docker image..." -ForegroundColor Yellow
$imageTag = "gcr.io/$ProjectId/proxy-service:latest"

Push-Location services/proxy-service

try {
    Write-Host "  Building image: $imageTag" -ForegroundColor Gray
    docker build -t $imageTag .
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Docker image built successfully" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Docker build failed" -ForegroundColor Red
        Pop-Location
        exit 1
    }
    
    # Push to Container Registry
    Write-Host "  Pushing image to Container Registry..." -ForegroundColor Gray
    docker push $imageTag
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Image pushed successfully" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Failed to push image" -ForegroundColor Red
        Pop-Location
        exit 1
    }
} catch {
    Write-Host "  ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Pop-Location
    exit 1
} finally {
    Pop-Location
}

Write-Host ""

# Step 3: Deploy to Cloud Run
Write-Host "Step 3: Deploying to Cloud Run..." -ForegroundColor Yellow
try {
    Write-Host "  Deploying proxy-service..." -ForegroundColor Gray
    
    gcloud run deploy proxy-service `
        --image $imageTag `
        --region $Region `
        --platform managed `
        --allow-unauthenticated `
        --service-account proxy-service@$ProjectId.iam.gserviceaccount.com `
        --set-env-vars "ORCHESTRATION_SERVICE_URL=$OrchestrationServiceUrl" `
        --port 8080 `
        --memory 512Mi `
        --cpu 1 `
        --max-instances 10 `
        --project $ProjectId
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Proxy service deployed successfully" -ForegroundColor Green
        
        # Get the service URL
        $serviceUrl = (gcloud run services describe proxy-service `
            --region=$Region `
            --project=$ProjectId `
            --format="value(status.url)")
        
        Write-Host "  Service URL: $serviceUrl" -ForegroundColor Cyan
    } else {
        Write-Host "  ❌ Deployment failed" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "  ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 4: Grant Service Account Access to Orchestration Service
Write-Host "Step 4: Granting service account access..." -ForegroundColor Yellow
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
        Write-Host "  ❌ Failed to grant permissions" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "  ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 5: Test the deployment
Write-Host "Step 5: Testing deployment..." -ForegroundColor Yellow
try {
    $serviceUrl = (gcloud run services describe proxy-service `
        --region=$Region `
        --project=$ProjectId `
        --format="value(status.url)")
    
    Write-Host "  Testing health endpoint: $serviceUrl/health" -ForegroundColor Gray
    
    $healthResponse = Invoke-RestMethod -Uri "$serviceUrl/health" -TimeoutSec 10
    
    if ($healthResponse.status -eq "healthy") {
        Write-Host "  ✅ Health check passed" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  Health check returned unexpected response" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ⚠️  Health check failed: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "     This might be normal if the service is still starting up" -ForegroundColor Gray
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
