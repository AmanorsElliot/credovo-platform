# PowerShell script to help set up GitHub Actions secrets
# This script creates a service account and outputs the key for GitHub secrets

param(
    [string]$ProjectId = "credovo-platform-dev"
)

Write-Host "=== GitHub Actions Secrets Setup ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Create service account for GitHub Actions
Write-Host "Step 1: Creating GitHub Actions service account..." -ForegroundColor Yellow
$serviceAccountEmail = "github-actions@${ProjectId}.iam.gserviceaccount.com"

# Check if service account exists
$saExists = gcloud iam service-accounts describe $serviceAccountEmail --project=$ProjectId 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Creating service account..." -ForegroundColor Yellow
    gcloud iam service-accounts create github-actions `
        --display-name="GitHub Actions Service Account" `
        --project=$ProjectId
} else {
    Write-Host "Service account already exists." -ForegroundColor Green
}

# Step 2: Grant necessary permissions
Write-Host ""
Write-Host "Step 2: Granting permissions..." -ForegroundColor Yellow

$roles = @(
    "roles/run.admin",
    "roles/artifactregistry.writer",
    "roles/iam.serviceAccountUser",
    "roles/cloudbuild.builds.editor",
    "roles/secretmanager.secretAccessor",
    "roles/storage.admin"
)

foreach ($role in $roles) {
    Write-Host "Granting $role..." -ForegroundColor Cyan
    gcloud projects add-iam-policy-binding $ProjectId `
        --member="serviceAccount:$serviceAccountEmail" `
        --role=$role `
        --condition=None
}

# Step 3: Create and download service account key
Write-Host ""
Write-Host "Step 3: Creating service account key..." -ForegroundColor Yellow
$keyFile = "github-actions-key.json"

if (Test-Path $keyFile) {
    $overwrite = Read-Host "Key file already exists. Overwrite? (yes/no)"
    if ($overwrite -ne "yes") {
        Write-Host "Using existing key file." -ForegroundColor Yellow
    } else {
        Remove-Item $keyFile -Force
        gcloud iam service-accounts keys create $keyFile `
            --iam-account=$serviceAccountEmail `
            --project=$ProjectId
    }
} else {
    gcloud iam service-accounts keys create $keyFile `
        --iam-account=$serviceAccountEmail `
        --project=$ProjectId
}

# Step 4: Display secrets for GitHub
Write-Host ""
Write-Host "=== GitHub Secrets Configuration ===" -ForegroundColor Green
Write-Host ""
Write-Host "Go to: https://github.com/AmanorsElliot/credovo-platform/settings/secrets/actions" -ForegroundColor Cyan
Write-Host ""
Write-Host "Add these secrets:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. GCP_PROJECT_ID" -ForegroundColor White
Write-Host "   Value: $ProjectId" -ForegroundColor Gray
Write-Host ""
Write-Host "2. GCP_SA_KEY" -ForegroundColor White
Write-Host "   Value: (see key file content below)" -ForegroundColor Gray
Write-Host ""
Write-Host "3. ARTIFACT_REGISTRY" -ForegroundColor White
Write-Host "   Value: credovo-services" -ForegroundColor Gray
Write-Host ""

# Read and display key file
Write-Host "Service Account Key JSON:" -ForegroundColor Yellow
Write-Host "=========================" -ForegroundColor Yellow
Get-Content $keyFile | Write-Host
Write-Host "=========================" -ForegroundColor Yellow
Write-Host ""

# Security reminder
Write-Host "IMPORTANT:" -ForegroundColor Red
Write-Host "- Copy the JSON above and paste it as the GCP_SA_KEY secret in GitHub" -ForegroundColor Yellow
Write-Host "- Delete the local key file after copying: Remove-Item $keyFile" -ForegroundColor Yellow
Write-Host "- Never commit the key file to git!" -ForegroundColor Yellow
Write-Host ""

$deleteNow = Read-Host "Delete the key file now? (yes/no)"
if ($deleteNow -eq "yes") {
    Remove-Item $keyFile -Force
    Write-Host "Key file deleted." -ForegroundColor Green
} else {
    Write-Host "Remember to delete $keyFile after copying the secret!" -ForegroundColor Yellow
}

