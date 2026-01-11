# Configure Frontend URL for CORS
# This script sets the Lovable frontend URL in GCP Secret Manager

param(
    [Parameter(Mandatory=$true)]
    [string]$FrontendUrl,

    [Parameter(Mandatory=$false)]
    [string]$ProjectId = "credovo-eu-apps-nonprod",

    [Parameter(Mandatory=$false)]
    [string]$Region = "europe-west1"
)

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "=== Configuring Frontend URL for CORS ===" -ForegroundColor Cyan
Write-Host "Project: $ProjectId" -ForegroundColor Gray
Write-Host "Frontend URL: $FrontendUrl" -ForegroundColor Gray

$SecretName = "lovable-frontend-url"

# Check if secret exists
Write-Host ""
Write-Host "Checking if secret exists..." -ForegroundColor Cyan
$null = gcloud secrets describe $SecretName --project=$ProjectId 2>&1 | Out-Null
$secretExists = $LASTEXITCODE -eq 0

if (-not $secretExists) {
    Write-Host "Secret '$SecretName' does not exist. Creating it..." -ForegroundColor Yellow
    $null = gcloud secrets create $SecretName --project=$ProjectId --replication-policy="user-managed" --locations=$Region 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to create secret '$SecretName'" -ForegroundColor Red
        exit 1
    }
    Write-Host "Secret '$SecretName' created successfully." -ForegroundColor Green
} else {
    Write-Host "Secret '$SecretName' already exists." -ForegroundColor Green
}

# Add new secret version
Write-Host ""
Write-Host "Adding new secret version..." -ForegroundColor Cyan
$ErrorActionPreference = "Stop"
echo $FrontendUrl | gcloud secrets versions add $SecretName --project=$ProjectId --data-file=-

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Successfully configured frontend URL!" -ForegroundColor Green
    Write-Host "Secret: $SecretName" -ForegroundColor Gray
    Write-Host "Frontend URL: $FrontendUrl" -ForegroundColor Gray

    # Verify the secret
    Write-Host ""
    Write-Host "Verifying secret..." -ForegroundColor Cyan
    $version = gcloud secrets versions list $SecretName --project=$ProjectId --limit=1 --format="value(name)" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Latest version: $version" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. The orchestration service will automatically use this URL for CORS" -ForegroundColor Gray
    Write-Host "2. Restart the orchestration service if it's already running:" -ForegroundColor Gray
    Write-Host "   gcloud run services update orchestration-service --region=$Region --project=$ProjectId" -ForegroundColor Gray
    Write-Host "3. Test CORS by making a request from your frontend" -ForegroundColor Gray
} else {
    Write-Host ""
    Write-Host "Failed to configure secret" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== Configuration Complete ===" -ForegroundColor Cyan
