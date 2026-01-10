# Setup a single Cloud Build trigger that builds all services in parallel
# This replaces the individual service triggers for better concurrency

param(
    [string]$ProjectId = "credovo-eu-apps-nonprod",
    [string]$Region = "europe-west1",
    [string]$RepoOwner = "AmanorsElliot",
    [string]$RepoName = "credovo-platform",
    [string]$BranchPattern = "^main$",
    [string]$ServiceAccount = "github-actions@credovo-eu-apps-nonprod.iam.gserviceaccount.com"
)

$ErrorActionPreference = "Stop"

Write-Host "=== Setting Up Parallel Build Trigger ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Project: $ProjectId" -ForegroundColor Gray
Write-Host "Region: $Region" -ForegroundColor Gray
Write-Host "Repository: $RepoOwner/$RepoName" -ForegroundColor Gray
Write-Host ""

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

$triggerName = "deploy-all-services-parallel"

# Check if trigger already exists
$existing = gcloud builds triggers list --region=$Region --project=$ProjectId --filter="name:$triggerName" --format="value(name)" 2>&1

if ($existing) {
    Write-Host "⚠️  Trigger already exists, updating..." -ForegroundColor Yellow
    $connectionName = "credovo-platform"
    gcloud builds triggers update github `
        --name=$triggerName `
        --region=$Region `
        --connection=$connectionName `
        --repo-name=$RepoName `
        --repo-owner=$RepoOwner `
        --branch-pattern=$BranchPattern `
        --build-config="cloudbuild.yaml" `
        --substitutions="_REGION=$Region,_ARTIFACT_REGISTRY=credovo-services" `
        --service-account=$ServiceAccount `
        --project=$ProjectId 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Trigger updated: $triggerName" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Failed to update trigger" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Creating trigger for parallel builds..." -ForegroundColor Cyan
    
    # Create the trigger
    # Use comma-separated substitutions (same format as individual service triggers)
    # Note: For GitHub triggers, we need to specify the connection name
    $connectionName = "credovo-platform"
    
    Write-Host "Creating trigger with connection: $connectionName" -ForegroundColor Gray
    gcloud builds triggers create github `
        --name=$triggerName `
        --region=$Region `
        --connection=$connectionName `
        --repo-name=$RepoName `
        --repo-owner=$RepoOwner `
        --branch-pattern=$BranchPattern `
        --build-config="cloudbuild.yaml" `
        --substitutions="_REGION=$Region,_ARTIFACT_REGISTRY=credovo-services" `
        --service-account=$ServiceAccount `
        --project=$ProjectId 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Trigger created: $triggerName" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Failed to create trigger" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "✅ Parallel build trigger created/updated: $triggerName" -ForegroundColor Green
Write-Host ""
Write-Host "This trigger will:" -ForegroundColor Yellow
Write-Host "  • Build all 3 services concurrently" -ForegroundColor White
Write-Host "  • Push all images concurrently" -ForegroundColor White
Write-Host "  • Deploy all services concurrently" -ForegroundColor White
Write-Host ""
Write-Host "View trigger:" -ForegroundColor Cyan
Write-Host "https://console.cloud.google.com/cloud-build/triggers?project=$ProjectId" -ForegroundColor Gray
Write-Host ""
Write-Host "Optional: Disable individual service triggers to avoid duplicate builds:" -ForegroundColor Yellow
Write-Host "  gcloud builds triggers update deploy-orchestration-service --disabled --region=$Region --project=$ProjectId" -ForegroundColor Gray
Write-Host "  gcloud builds triggers update deploy-kyc-kyb-service --disabled --region=$Region --project=$ProjectId" -ForegroundColor Gray
Write-Host "  gcloud builds triggers update deploy-connector-service --disabled --region=$Region --project=$ProjectId" -ForegroundColor Gray
Write-Host ""

