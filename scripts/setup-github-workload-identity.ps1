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
# Use a new pool name to avoid the deleted pool
$poolId = "github-actions-pool-v2"
$providerId = "github-provider"

# Check if provider exists and delete it
Write-Host "Checking for existing provider..." -ForegroundColor Cyan
$providerCheck = gcloud iam workload-identity-pools providers describe $providerId `
    --workload-identity-pool=$poolId `
    --location=global `
    --project=$ProjectId 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "Deleting existing provider..." -ForegroundColor Cyan
    gcloud iam workload-identity-pools providers delete $providerId `
        --workload-identity-pool=$poolId `
        --location=global `
        --project=$ProjectId `
        --quiet
    Start-Sleep -Seconds 2
}

# Check if pool exists and delete it
Write-Host "Checking for existing pool..." -ForegroundColor Cyan
$poolCheck = gcloud iam workload-identity-pools describe $poolId `
    --location=global `
    --project=$ProjectId 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "Deleting existing pool..." -ForegroundColor Cyan
    gcloud iam workload-identity-pools delete $poolId `
        --location=global `
        --project=$ProjectId `
        --quiet
    Start-Sleep -Seconds 3
}

# Step 4: Create Workload Identity Pool (or use existing)
Write-Host ""
Write-Host "Step 4: Creating Workload Identity Pool..." -ForegroundColor Yellow
$poolName = "projects/$ProjectId/locations/global/workloadIdentityPools/$poolId"

# Try to create pool, ignore if it already exists
$poolCreate = gcloud iam workload-identity-pools create $poolId `
    --location=global `
    --project=$ProjectId `
    --display-name="GitHub Actions Pool" 2>&1

if ($LASTEXITCODE -ne 0 -and $poolCreate -notmatch "ALREADY_EXISTS") {
    Write-Host "ERROR: Failed to create pool: $poolCreate" -ForegroundColor Red
    exit 1
} else {
    Write-Host "Pool ready (created or already exists)." -ForegroundColor Green
}

# Step 5: Delete existing provider if it exists (might have wrong config)
Write-Host ""
Write-Host "Step 5: Ensuring provider is clean..." -ForegroundColor Yellow

# Try to delete provider (ignore errors)
gcloud iam workload-identity-pools providers delete $providerId `
    --workload-identity-pool=$poolId `
    --location=global `
    --project=$ProjectId `
    --quiet 2>&1 | Out-Null

Start-Sleep -Seconds 2

# Create Workload Identity Provider (simple, no condition)
Write-Host "Creating Workload Identity Provider..." -ForegroundColor Yellow
$providerName = "$poolName/providers/$providerId"

# Create provider with minimal mapping - no condition, no extra attributes
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
Start-Sleep -Seconds 3

# Get project number (needed for principal format)
$projectNumber = (gcloud projects describe $ProjectId --format="value(projectNumber)")

# Use the correct principal format - need to use the full resource name
# Format: principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/POOL_ID
$principal = "principalSet://iam.googleapis.com/projects/$projectNumber/locations/global/workloadIdentityPools/$poolId"

Write-Host "Using principal: $principal" -ForegroundColor Gray
Write-Host "Waiting for provider to be fully ready..." -ForegroundColor Cyan
Start-Sleep -Seconds 3

# Try to add IAM binding
Write-Host "Adding IAM policy binding..." -ForegroundColor Cyan
gcloud iam service-accounts add-iam-policy-binding $serviceAccountEmail `
    --project=$ProjectId `
    --role="roles/iam.workloadIdentityUser" `
    --member="$principal"

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "WARNING: IAM binding failed. You may need to add it manually:" -ForegroundColor Yellow
    Write-Host "  gcloud iam service-accounts add-iam-policy-binding $serviceAccountEmail \`" -ForegroundColor Gray
    Write-Host "    --project=$ProjectId \`" -ForegroundColor Gray
    Write-Host "    --role='roles/iam.workloadIdentityUser' \`" -ForegroundColor Gray
    Write-Host "    --member='$principal'" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Or try using the pool resource name directly from the GCP Console." -ForegroundColor Yellow
}

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
Write-Host "Note: You do NOT need GCP_SA_KEY anymore - Workload Identity Federation replaces it" -ForegroundColor Green
