# Configure The Companies API Secret in GCP Secret Manager
# This script stores the API key for The Companies API

param(
    [Parameter(Mandatory=$false)]
    [string]$ProjectId = "credovo-eu-apps-nonprod",
    
    [Parameter(Mandatory=$false)]
    [string]$Region = "europe-west1",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("production", "sandbox")]
    [string]$Environment = "production"
)

$ErrorActionPreference = "Stop"

Write-Host "`n=== Configuring The Companies API Secret ===" -ForegroundColor Cyan
Write-Host "Project: $ProjectId" -ForegroundColor Gray
Write-Host "Environment: $Environment" -ForegroundColor Gray

# Set the API key based on environment
if ($Environment -eq "production") {
    $ApiKey = "7p4EEUJmvJf4JhQuWSRnIlQ3V10R6TCK"
    Write-Host "Using Production API Key" -ForegroundColor Green
} else {
    $ApiKey = "VuCovB9Ka9mu0M2BeVcblTj1kw27TR9k"
    Write-Host "Using Sandbox API Key" -ForegroundColor Yellow
}

$SecretName = "companies-api-api-key"

# Check if secret exists
Write-Host "`nChecking if secret exists..." -ForegroundColor Cyan
$secretExists = gcloud secrets describe $SecretName --project=$ProjectId 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "Secret does not exist. Please create it via Terraform first." -ForegroundColor Red
    Write-Host "Run: terraform apply in infrastructure/terraform/" -ForegroundColor Yellow
    exit 1
}

# Add new secret version
Write-Host "`nAdding new secret version..." -ForegroundColor Cyan
echo $ApiKey | gcloud secrets versions add $SecretName --project=$ProjectId --data-file=-

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✅ Successfully configured The Companies API secret!" -ForegroundColor Green
    Write-Host "Secret: $SecretName" -ForegroundColor Gray
    Write-Host "Environment: $Environment" -ForegroundColor Gray
    
    # Verify the secret
    Write-Host "`nVerifying secret..." -ForegroundColor Cyan
    $version = gcloud secrets versions list $SecretName --project=$ProjectId --limit=1 --format="value(name)" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Latest version: $version" -ForegroundColor Green
    }
} else {
    Write-Host "`n❌ Failed to configure secret" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== Configuration Complete ===" -ForegroundColor Cyan
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. The secret is now available to the connector-service" -ForegroundColor Gray
Write-Host "2. Restart the connector-service if it's already running" -ForegroundColor Gray
Write-Host "3. Test the company search endpoint: GET /api/v1/companies/search?query=test" -ForegroundColor Gray
