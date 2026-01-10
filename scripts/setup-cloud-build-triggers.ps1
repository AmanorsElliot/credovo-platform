# Setup Cloud Build Triggers for GitHub Integration
# Run this AFTER completing the OAuth connection in GCP Console

param(
    [string]$ProjectId = "credovo-eu-apps-nonprod",
    [string]$Region = "europe-west1",
    [string]$ArtifactRegistry = "credovo-services",
    [string]$RepoOwner = "AmanorsElliot",
    [string]$RepoName = "credovo-platform",
    [string]$BranchPattern = "^main$",
    [string]$ServiceAccount = "github-actions@credovo-eu-apps-nonprod.iam.gserviceaccount.com"
)

$ErrorActionPreference = "Stop"

Write-Host "=== Setting Up Cloud Build Triggers ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Project: $ProjectId" -ForegroundColor Gray
Write-Host "Region: $Region" -ForegroundColor Gray
Write-Host "Repository: $RepoOwner/$RepoName" -ForegroundColor Gray
Write-Host ""

# Services to create triggers for
$services = @(
    "orchestration-service",
    "kyc-kyb-service",
    "connector-service"
)

Write-Host "Checking if connection exists..." -ForegroundColor Yellow
$connection = gcloud builds connections list --region=$Region --project=$ProjectId --filter="name:credovo-platform" --format="value(name)" 2>&1

if (-not $connection) {
    Write-Host "❌ Connection 'credovo-platform' not found!" -ForegroundColor Red
    Write-Host "Please complete the OAuth connection in GCP Console first:" -ForegroundColor Yellow
    Write-Host "https://console.cloud.google.com/cloud-build/connections?project=$ProjectId" -ForegroundColor Gray
    exit 1
}

Write-Host "✅ Connection found" -ForegroundColor Green
Write-Host ""

foreach ($service in $services) {
    Write-Host "Creating trigger for $service..." -ForegroundColor Cyan
    
    $triggerName = "deploy-$service"
    
    # Check if trigger already exists
    $existing = gcloud builds triggers list --region=$Region --project=$ProjectId --filter="name:$triggerName" --format="value(name)" 2>&1
    
    if ($existing) {
        Write-Host "  ⚠️  Trigger already exists, skipping..." -ForegroundColor Yellow
        continue
    }
    
    # Create the trigger
    gcloud builds triggers create github `
        --name=$triggerName `
        --region=$Region `
        --repo-name=$RepoName `
        --repo-owner=$RepoOwner `
        --branch-pattern=$BranchPattern `
        --build-config="services/$service/cloudbuild.yaml" `
        --substitutions="_REGION=$Region,_ARTIFACT_REGISTRY=$ArtifactRegistry,_SERVICE_NAME=$service" `
        --service-account=$ServiceAccount `
        --project=$ProjectId 2>&1 | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Trigger created: $triggerName" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Failed to create trigger" -ForegroundColor Red
    }
    
    Write-Host ""
}

Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Created triggers for:" -ForegroundColor Green
foreach ($service in $services) {
    Write-Host "  - deploy-$service" -ForegroundColor White
}

Write-Host ""
Write-Host "View triggers:" -ForegroundColor Cyan
Write-Host "https://console.cloud.google.com/cloud-build/triggers?project=$ProjectId" -ForegroundColor Gray
Write-Host ""
Write-Host "Test by pushing to the main branch!" -ForegroundColor Green

