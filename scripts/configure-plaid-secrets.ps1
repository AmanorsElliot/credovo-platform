# Configure Plaid secrets in GCP Secret Manager
# Run this script to add Plaid credentials to Secret Manager

param(
    [string]$ProjectId = "credovo-eu-apps-nonprod",
    [string]$ClientId = "",
    [string]$SandboxSecret = "",
    [string]$ProductionSecret = "",
    [switch]$UseProduction = $false
)

$ErrorActionPreference = "Stop"

Write-Host "=== Configuring Plaid Secrets in GCP Secret Manager ===" -ForegroundColor Cyan
Write-Host ""

# Set project
gcloud config set project $ProjectId

# Use provided credentials or prompt
if ([string]::IsNullOrEmpty($ClientId)) {
    $ClientId = Read-Host "Enter Plaid Client ID"
}

if ([string]::IsNullOrEmpty($SandboxSecret)) {
    $SandboxSecret = Read-Host "Enter Plaid Sandbox Secret" -AsSecureString
    $SandboxSecret = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SandboxSecret)
    )
}

if ([string]::IsNullOrEmpty($ProductionSecret)) {
    $ProductionSecret = Read-Host "Enter Plaid Production Secret (optional)" -AsSecureString
    $ProductionSecret = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($ProductionSecret)
    )
}

# Determine which secret to use
$secretToUse = if ($UseProduction) { $ProductionSecret } else { $SandboxSecret }
$envLabel = if ($UseProduction) { "production" } else { "sandbox" }

Write-Host ""
Write-Host "Configuring Plaid secrets for: $envLabel environment" -ForegroundColor Yellow
Write-Host ""

# 1. Plaid Client ID (same for both environments)
Write-Host "Adding Plaid Client ID..." -ForegroundColor Yellow
try {
    # Check if secret exists
    $exists = gcloud secrets describe plaid-client-id --project=$ProjectId 2>&1
    if ($LASTEXITCODE -eq 0) {
        # Secret exists, add new version
        $ClientId | gcloud secrets versions add plaid-client-id --data-file=- --project=$ProjectId
        Write-Host "  [OK] Plaid Client ID updated" -ForegroundColor Green
    } else {
        # Create new secret with regional replication
        echo $ClientId | gcloud secrets create plaid-client-id --data-file=- --project=$ProjectId --replication-policy="user-managed" --locations="europe-west1"
        Write-Host "  [OK] Plaid Client ID created" -ForegroundColor Green
    }
} catch {
    Write-Host "  [FAIL] Failed to configure Plaid Client ID: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 2. Plaid Secret Key (sandbox or production)
Write-Host ""
Write-Host "Adding Plaid Secret Key ($envLabel)..." -ForegroundColor Yellow
try {
    $secretName = "plaid-secret-key"
    if ($UseProduction) {
        $secretName = "plaid-secret-key-prod"
    }
    
    # Check if secret exists
    $exists = gcloud secrets describe $secretName --project=$ProjectId 2>&1
    if ($LASTEXITCODE -eq 0) {
        # Secret exists, add new version
        $secretToUse | gcloud secrets versions add $secretName --data-file=- --project=$ProjectId
        Write-Host "  [OK] Plaid Secret Key ($envLabel) updated" -ForegroundColor Green
    } else {
        # Create new secret with regional replication
        echo $secretToUse | gcloud secrets create $secretName --data-file=- --project=$ProjectId --replication-policy="user-managed" --locations="europe-west1"
        Write-Host "  [OK] Plaid Secret Key ($envLabel) created" -ForegroundColor Green
    }
} catch {
    Write-Host "  [FAIL] Failed to configure Plaid Secret Key: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 3. If production secret provided, also create production secret
if (-not [string]::IsNullOrEmpty($ProductionSecret) -and -not $UseProduction) {
    Write-Host ""
    Write-Host "Adding Plaid Production Secret Key..." -ForegroundColor Yellow
    try {
        $secretName = "plaid-secret-key-prod"
        
        # Check if secret exists
        $exists = gcloud secrets describe $secretName --project=$ProjectId 2>&1
        if ($LASTEXITCODE -eq 0) {
            # Secret exists, add new version
            $ProductionSecret | gcloud secrets versions add $secretName --data-file=- --project=$ProjectId
            Write-Host "  [OK] Plaid Production Secret Key updated" -ForegroundColor Green
        } else {
            # Create new secret with regional replication
            echo $ProductionSecret | gcloud secrets create $secretName --data-file=- --project=$ProjectId --replication-policy="user-managed" --locations="europe-west1"
            Write-Host "  [OK] Plaid Production Secret Key created" -ForegroundColor Green
        }
    } catch {
        Write-Host "  [WARN] Failed to configure Plaid Production Secret Key: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "  You can add it later manually" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "=== Plaid Secrets Configuration Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Secrets created/updated:" -ForegroundColor White
Write-Host "  - plaid-client-id" -ForegroundColor Gray
Write-Host "  - plaid-secret-key ($envLabel)" -ForegroundColor Gray
if (-not [string]::IsNullOrEmpty($ProductionSecret) -and -not $UseProduction) {
    Write-Host "  - plaid-secret-key-prod" -ForegroundColor Gray
}
Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  1. Update Terraform to reference these secrets" -ForegroundColor Gray
Write-Host "  2. Update Cloud Run services to use PLAID_CLIENT_ID and PLAID_SECRET_KEY env vars" -ForegroundColor Gray
Write-Host "  3. Set PLAID_ENV=sandbox (or production) in Cloud Run" -ForegroundColor Gray
Write-Host ""
