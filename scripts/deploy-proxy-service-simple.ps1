# Simple Proxy Service Deployment
# This script creates the service account and deploys using gcloud run deploy
# Note: You'll need to build the image first via Cloud Build or manually

param(
    [string]$ProjectId = "credovo-eu-apps-nonprod",
    [string]$Region = "europe-west1",
    [string]$ImageTag = "",
    [string]$OrchestrationServiceUrl = "https://orchestration-service-saz24fo3sa-ew.a.run.app"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deploying Proxy Service (Simple)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# If no image tag provided, we'll need to build it first
if (-not $ImageTag) {
    Write-Host "No image tag provided. Building via Cloud Build..." -ForegroundColor Yellow
    
    # Use a simple inline build
    $buildConfig = @"
steps:
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'build'
      - '-t'
      - 'europe-west1-docker.pkg.dev/$ProjectId/credovo-services/proxy-service:latest'
      - 'services/proxy-service'
  
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'push'
      - 'europe-west1-docker.pkg.dev/$ProjectId/credovo-services/proxy-service:latest'

options:
  machineType: 'E2_HIGHCPU_8'
  logging: CLOUD_LOGGING_ONLY
"@
    
    $buildConfig | Out-File -FilePath "temp-proxy-build.yaml" -Encoding utf8
    
    Write-Host "Submitting build..." -ForegroundColor Gray
    gcloud builds submit --config=temp-proxy-build.yaml --region=$Region --project=$ProjectId
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Build failed. Trying alternative method..." -ForegroundColor Yellow
        Remove-Item "temp-proxy-build.yaml" -ErrorAction SilentlyContinue
        
        # Alternative: Deploy from source
        Write-Host "Deploying from source..." -ForegroundColor Gray
        gcloud run deploy proxy-service `
            --source services/proxy-service `
            --region=$Region `
            --platform managed `
            --allow-unauthenticated `
            --service-account proxy-service@$ProjectId.iam.gserviceaccount.com `
            --set-env-vars "ORCHESTRATION_SERVICE_URL=$OrchestrationServiceUrl" `
            --port 8080 `
            --memory 512Mi `
            --cpu 1 `
            --max-instances 10 `
            --project=$ProjectId
        
        if ($LASTEXITCODE -eq 0) {
            $ImageTag = "europe-west1-docker.pkg.dev/$ProjectId/credovo-services/proxy-service:latest"
        }
    } else {
        $ImageTag = "europe-west1-docker.pkg.dev/$ProjectId/credovo-services/proxy-service:latest"
        Remove-Item "temp-proxy-build.yaml" -ErrorAction SilentlyContinue
    }
}

# Step 1: Ensure service account exists
Write-Host "`nStep 1: Checking service account..." -ForegroundColor Yellow
try {
    gcloud iam service-accounts describe proxy-service@$ProjectId.iam.gserviceaccount.com `
        --project=$ProjectId 2>&1 | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Service account exists" -ForegroundColor Green
    }
} catch {
    Write-Host "  Creating service account..." -ForegroundColor Gray
    gcloud iam service-accounts create proxy-service `
        --display-name="Proxy Service Account" `
        --description="Service account for proxy service" `
        --project=$ProjectId
}

# Step 2: Deploy to Cloud Run
if ($ImageTag) {
    Write-Host "`nStep 2: Deploying with image: $ImageTag" -ForegroundColor Yellow
    gcloud run deploy proxy-service `
        --image $ImageTag `
        --region=$Region `
        --platform managed `
        --allow-unauthenticated `
        --service-account proxy-service@$ProjectId.iam.gserviceaccount.com `
        --set-env-vars "ORCHESTRATION_SERVICE_URL=$OrchestrationServiceUrl" `
        --port 8080 `
        --memory 512Mi `
        --cpu 1 `
        --max-instances 10 `
        --project=$ProjectId
} else {
    Write-Host "`nStep 2: Deploying from source..." -ForegroundColor Yellow
    gcloud run deploy proxy-service `
        --source services/proxy-service `
        --region=$Region `
        --platform managed `
        --allow-unauthenticated `
        --service-account proxy-service@$ProjectId.iam.gserviceaccount.com `
        --set-env-vars "ORCHESTRATION_SERVICE_URL=$OrchestrationServiceUrl" `
        --port 8080 `
        --memory 512Mi `
        --cpu 1 `
        --max-instances 10 `
        --project=$ProjectId
}

# Step 3: Grant permissions
Write-Host "`nStep 3: Granting permissions..." -ForegroundColor Yellow
gcloud run services add-iam-policy-binding orchestration-service `
    --region=$Region `
    --member="serviceAccount:proxy-service@$ProjectId.iam.gserviceaccount.com" `
    --role=roles/run.invoker `
    --project=$ProjectId

# Step 4: Get URL
Write-Host "`nStep 4: Getting service URL..." -ForegroundColor Yellow
$serviceUrl = (gcloud run services describe proxy-service `
    --region=$Region `
    --project=$ProjectId `
    --format="value(status.url)")

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Proxy Service URL: $serviceUrl" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Update Edge Function: PROXY_SERVICE_URL=$serviceUrl" -ForegroundColor White
Write-Host "2. Test: Invoke-RestMethod -Uri '$serviceUrl/health'" -ForegroundColor White
