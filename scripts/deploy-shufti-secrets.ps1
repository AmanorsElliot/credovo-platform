# Deploy Shufti Pro secrets to GCP Secret Manager using Terraform
# Run this script from the repository root

param(
    [switch]$SkipAuth
)

$ErrorActionPreference = "Stop"

Write-Host "=== Deploying Shufti Pro Secrets to Secret Manager ===" -ForegroundColor Cyan
Write-Host ""

# Check if authenticated
if (-not $SkipAuth) {
    Write-Host "Checking authentication..." -ForegroundColor Yellow
    $authCheck = gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>&1
    if (-not $authCheck -or $authCheck -match "ERROR") {
        Write-Host "❌ Not authenticated. Please run:" -ForegroundColor Red
        Write-Host "   gcloud auth application-default login" -ForegroundColor Yellow
        Write-Host "   OR" -ForegroundColor Yellow
        Write-Host "   gcloud auth login" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "✅ Authenticated as: $authCheck" -ForegroundColor Green
    Write-Host ""
}

# Navigate to terraform directory
$terraformDir = Join-Path $PSScriptRoot "..\infrastructure\terraform"
if (-not (Test-Path $terraformDir)) {
    Write-Host "❌ Terraform directory not found: $terraformDir" -ForegroundColor Red
    exit 1
}

Push-Location $terraformDir

try {
    Write-Host "Initializing Terraform..." -ForegroundColor Yellow
    terraform init -upgrade 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Terraform init failed" -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ Terraform initialized" -ForegroundColor Green
    Write-Host ""

    Write-Host "Applying Terraform to create Shufti Pro secrets..." -ForegroundColor Yellow
    Write-Host ""
    
    terraform apply `
        -target='google_secret_manager_secret.shufti_pro_client_id' `
        -target='google_secret_manager_secret.shufti_pro_secret_key' `
        -target='google_secret_manager_secret_version.shufti_pro_client_id_version' `
        -target='google_secret_manager_secret_version.shufti_pro_secret_key_version' `
        -auto-approve

    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✅ Shufti Pro secrets successfully deployed to Secret Manager!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Secrets created:" -ForegroundColor Cyan
        Write-Host "  - shufti-pro-client-id" -ForegroundColor White
        Write-Host "  - shufti-pro-secret-key" -ForegroundColor White
        Write-Host ""
        Write-Host "Next: Update connector service with terraform apply (or it will be updated on next deployment)" -ForegroundColor Yellow
    } else {
        Write-Host ""
        Write-Host "❌ Terraform apply failed. Check the errors above." -ForegroundColor Red
        exit 1
    }
} finally {
    Pop-Location
}

