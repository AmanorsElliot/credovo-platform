# Deploy a service directly to Cloud Run using Docker build and gcloud deploy
# This bypasses Cloud Build region constraints

param(
    [Parameter(Mandatory=$true)]
    [string]$ServiceName,
    [string]$ProjectId = "credovo-eu-apps-nonprod",
    [string]$Region = "europe-west1",
    [string]$ArtifactRegistry = "credovo-services"
)

$ErrorActionPreference = "Stop"

Write-Host "=== Deploying $ServiceName to Cloud Run ===" -ForegroundColor Cyan
Write-Host "Project: $ProjectId" -ForegroundColor Gray
Write-Host "Region: $Region" -ForegroundColor Gray
Write-Host ""

# Set GCP project
gcloud config set project $ProjectId

$imageTag = "$Region-docker.pkg.dev/$ProjectId/$ArtifactRegistry/$ServiceName:latest"
$servicePath = "services/$ServiceName"

if (-not (Test-Path $servicePath)) {
    Write-Host "Error: Service path $servicePath not found" -ForegroundColor Red
    exit 1
}

Write-Host "Step 1: Building Docker image..." -ForegroundColor Yellow
docker build -t $imageTag -f "$servicePath/Dockerfile" .

if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker build failed" -ForegroundColor Red
    exit 1
}

Write-Host "Step 2: Pushing image to Artifact Registry..." -ForegroundColor Yellow
docker push $imageTag

if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker push failed" -ForegroundColor Red
    exit 1
}

Write-Host "Step 3: Deploying to Cloud Run..." -ForegroundColor Yellow

# Build the gcloud run deploy command with all necessary flags
$deployArgs = @(
    "run", "deploy", $ServiceName,
    "--image", $imageTag,
    "--region", $Region,
    "--platform", "managed",
    "--service-account", "$ServiceName@$ProjectId.iam.gserviceaccount.com",
    "--allow-unauthenticated"
)

# Add environment variables from Secret Manager
# Note: These are already configured in Terraform, but we need to ensure they're set
# The secrets are already referenced in the Cloud Run service via Terraform

gcloud @deployArgs

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "$ServiceName deployed successfully!" -ForegroundColor Green
    $url = gcloud run services describe $ServiceName --region=$Region --project=$ProjectId --format="value(status.url)" 2>&1
    Write-Host "Service URL: $url" -ForegroundColor Green
} else {
    Write-Host "Deployment failed" -ForegroundColor Red
    exit 1
}

