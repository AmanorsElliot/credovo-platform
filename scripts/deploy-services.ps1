# PowerShell script to build and deploy services to Cloud Run
# This builds Docker images, pushes to Artifact Registry, and deploys to Cloud Run

param(
    [string[]]$Services = @("orchestration-service", "kyc-kyb-service", "connector-service"),
    [string]$ProjectId = "credovo-eu-apps-nonprod",
    [string]$Region = "europe-west1",
    [string]$ArtifactRegistry = "credovo-services"
)

$ErrorActionPreference = "Stop"

Write-Host "=== Deploying Services to Cloud Run ===" -ForegroundColor Cyan
Write-Host "Project: $ProjectId" -ForegroundColor Gray
Write-Host "Region: $Region" -ForegroundColor Gray
Write-Host "Artifact Registry: $ArtifactRegistry" -ForegroundColor Gray
Write-Host ""

# Set GCP project
gcloud config set project $ProjectId

# Configure Docker for Artifact Registry
Write-Host "Configuring Docker for Artifact Registry..." -ForegroundColor Yellow
gcloud auth configure-docker "$Region-docker.pkg.dev" --quiet

foreach ($service in $Services) {
    Write-Host ""
    Write-Host "=== Deploying $service ===" -ForegroundColor Cyan
    
    $imageTag = "$Region-docker.pkg.dev/$ProjectId/$ArtifactRegistry/$service"
    $servicePath = "services/$service"
    
    # Check if service directory exists
    if (-not (Test-Path $servicePath)) {
        Write-Host "⚠ Service directory not found: $servicePath" -ForegroundColor Yellow
        continue
    }
    
    # Check if Dockerfile exists
    if (-not (Test-Path "$servicePath/Dockerfile")) {
        Write-Host "⚠ Dockerfile not found: $servicePath/Dockerfile" -ForegroundColor Yellow
        continue
    }
    
    try {
        # Build Docker image
        Write-Host "Building Docker image..." -ForegroundColor Yellow
        docker build -f "$servicePath/Dockerfile" -t "$imageTag:latest" . 2>&1 | Out-Null
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ Docker build failed for $service" -ForegroundColor Red
            continue
        }
        
        # Push to Artifact Registry
        Write-Host "Pushing image to Artifact Registry..." -ForegroundColor Yellow
        docker push "$imageTag:latest" 2>&1 | Out-Null
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ Docker push failed for $service" -ForegroundColor Red
            continue
        }
        
        # Deploy to Cloud Run
        Write-Host "Deploying to Cloud Run..." -ForegroundColor Yellow
        gcloud run deploy $service `
            --image "$imageTag:latest" `
            --region $Region `
            --platform managed `
            --service-account "$service@$ProjectId.iam.gserviceaccount.com" `
            --allow-unauthenticated `
            --quiet 2>&1 | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Successfully deployed $service" -ForegroundColor Green
        } else {
            Write-Host "❌ Cloud Run deployment failed for $service" -ForegroundColor Red
        }
        
    } catch {
        Write-Host "❌ Error deploying $service : $_" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== Deployment Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "To get service URLs:" -ForegroundColor Cyan
Write-Host "  cd infrastructure/terraform" -ForegroundColor Gray
Write-Host "  terraform output" -ForegroundColor Gray

