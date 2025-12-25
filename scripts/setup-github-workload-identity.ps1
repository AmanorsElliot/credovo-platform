# PowerShell script to set up GitHub Actions with Workload Identity Federation
# This is the recommended approach when service account key creation is disabled

param(
    [string]$ProjectId = "credovo-platform-dev",
    [string]$GitHubRepo = "AmanorsElliot/credovo-platform"
)

Write-Host "=== GitHub Actions Workload Identity Federation Setup ===" -ForegroundColor Cyan
Write-Host ""

# Set project
gcloud config set project $ProjectId

# Step 1: Create service account for GitHub Actions (if it doesn't exist)
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
        --condition=None 2>&1 | Out-Null
}

# Step 3: Delete existing pool and provider if they exist (clean slate)
Write-Host ""
Write-Host "Step 3: Cleaning up existing Workload Identity resources..." -ForegroundColor Yellow
$poolId = "github-actions-pool"
$providerId = "github-provider"

# Delete provider first (if exists) - ignore errors
Write-Host "Deleting existing provider (if any)..." -ForegroundColor Cyan
gcloud iam workload-identity-pools providers delete $providerId `
    --workload-identity-pool=$poolId `
    --location=global `
    --project=$ProjectId `
    --quiet 2>&1 | Out-Null

# Delete pool (if exists) - ignore errors
Write-Host "Deleting existing pool (if any)..." -ForegroundColor Cyan
gcloud iam workload-identity-pools delete $poolId `
    --location=global `
    --project=$ProjectId `
    --quiet 2>&1 | Out-Null

# Wait a moment for deletion to complete
Start-Sleep -Seconds 3

# Step 4: Create Workload Identity Pool
Write-Host ""
Write-Host "Step 4: Creating Workload Identity Pool..." -ForegroundColor Yellow
$poolName = "projects/$ProjectId/locations/global/workloadIdentityPools/$poolId"

gcloud iam workload-identity-pools create $poolId `
    --location=global `
    --project=$ProjectId `
    --display-name="GitHub Actions Pool"

# Step 5: Create Workload Identity Provider (simple, no condition)
Write-Host ""
Write-Host "Step 5: Creating Workload Identity Provider..." -ForegroundColor Yellow
$providerName = "$poolName/providers/$providerId"

# Create provider with minimal mapping - no condition
gcloud iam workload-identity-pools providers create-oidc $providerId `
    --workload-identity-pool=$poolId `
    --location=global `
    --project=$ProjectId `
    --display-name="GitHub Provider" `
    --attribute-mapping="google.subject=assertion.sub" `
    --issuer-uri="https://token.actions.githubusercontent.com"

# Step 6: Allow GitHub Actions to impersonate the service account
Write-Host ""
Write-Host "Step 6: Granting GitHub Actions permission to impersonate service account..." -ForegroundColor Yellow

# Wait a moment for provider to be fully created
Start-Sleep -Seconds 2

# Use principalSet for all principals in the pool (simpler, less restrictive)
# You can restrict this later by repository if needed
$principal = "principalSet://iam.googleapis.com/$poolName"

gcloud iam service-accounts add-iam-policy-binding $serviceAccountEmail `
    --project=$ProjectId `
    --role="roles/iam.workloadIdentityUser" `
    --member="$principal"

Write-Host ""
Write-Host "=== Workload Identity Federation Setup Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Add these secrets to GitHub:" -ForegroundColor Cyan
Write-Host "Go to: https://github.com/$GitHubRepo/settings/secrets/actions" -ForegroundColor Yellow
Write-Host ""
Write-Host "Repository Secrets to add:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. GCP_PROJECT_ID" -ForegroundColor White
Write-Host "   Value: $ProjectId" -ForegroundColor Gray
Write-Host ""
Write-Host "2. GCP_WIF_PROVIDER" -ForegroundColor White
Write-Host "   Value: $providerName" -ForegroundColor Gray
Write-Host ""
Write-Host "3. GCP_WIF_SERVICE_ACCOUNT" -ForegroundColor White
Write-Host "   Value: $serviceAccountEmail" -ForegroundColor Gray
Write-Host ""
Write-Host "4. ARTIFACT_REGISTRY" -ForegroundColor White
Write-Host "   Value: credovo-services" -ForegroundColor Gray
Write-Host ""
Write-Host "Note: You do NOT need GCP_SA_KEY anymore - Workload Identity Federation replaces it!" -ForegroundColor Green
