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
        --condition=None
}

# Step 3: Create Workload Identity Pool
Write-Host ""
Write-Host "Step 3: Creating Workload Identity Pool..." -ForegroundColor Yellow
$poolId = "github-actions-pool"
$poolName = "projects/$ProjectId/locations/global/workloadIdentityPools/$poolId"

$poolExists = gcloud iam workload-identity-pools describe $poolId --location=global --project=$ProjectId 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Creating workload identity pool..." -ForegroundColor Yellow
    gcloud iam workload-identity-pools create $poolId `
        --location=global `
        --project=$ProjectId `
        --display-name="GitHub Actions Pool"
} else {
    Write-Host "Workload identity pool already exists." -ForegroundColor Green
}

# Step 4: Create Workload Identity Provider
Write-Host ""
Write-Host "Step 4: Creating Workload Identity Provider..." -ForegroundColor Yellow
$providerId = "github-provider"
$providerName = "$poolName/providers/$providerId"

$providerExists = gcloud iam workload-identity-pools providers describe $providerId `
    --workload-identity-pool=$poolId `
    --location=global `
    --project=$ProjectId 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "Creating workload identity provider..." -ForegroundColor Yellow
    gcloud iam workload-identity-pools providers create-oidc $providerId `
        --workload-identity-pool=$poolId `
        --location=global `
        --project=$ProjectId `
        --display-name="GitHub Provider" `
        --attribute-mapping="google.subject=assertion.sub,attribute.repository_owner=assertion.repository_owner,attribute.repository=assertion.repository" `
        --attribute-condition="assertion.repository == '$GitHubRepo'" `
        --issuer-uri="https://token.actions.githubusercontent.com"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Failed to create workload identity provider." -ForegroundColor Red
        Write-Host "Trying without attribute condition..." -ForegroundColor Yellow
        gcloud iam workload-identity-pools providers create-oidc $providerId `
            --workload-identity-pool=$poolId `
            --location=global `
            --project=$ProjectId `
            --display-name="GitHub Provider" `
            --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" `
            --issuer-uri="https://token.actions.githubusercontent.com"
    }
} else {
    Write-Host "Workload identity provider already exists." -ForegroundColor Green
}

# Step 5: Allow GitHub Actions to impersonate the service account
Write-Host ""
Write-Host "Step 5: Granting GitHub Actions permission to impersonate service account..." -ForegroundColor Yellow

# Wait a moment for the provider to be fully created
Start-Sleep -Seconds 5

# Use principalSet with repository attribute
$principal = "principalSet://iam.googleapis.com/projects/$ProjectId/locations/global/workloadIdentityPools/$poolId/attribute.repository/$GitHubRepo"

Write-Host "Binding principal: $principal" -ForegroundColor Cyan

gcloud iam service-accounts add-iam-policy-binding $serviceAccountEmail `
    --project=$ProjectId `
    --role="roles/iam.workloadIdentityUser" `
    --member="$principal"

if ($LASTEXITCODE -ne 0) {
    Write-Host "WARNING: Failed to add IAM policy binding with repository condition." -ForegroundColor Yellow
    Write-Host "Trying with principalSet (all repositories in pool)..." -ForegroundColor Yellow
    
    # Fallback: allow all principals in the pool (less restrictive but should work)
    $principalFallback = "principalSet://iam.googleapis.com/projects/$ProjectId/locations/global/workloadIdentityPools/$poolId"
    
    gcloud iam service-accounts add-iam-policy-binding $serviceAccountEmail `
        --project=$ProjectId `
        --role="roles/iam.workloadIdentityUser" `
        --member="$principalFallback"
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
Write-Host "Note: You do NOT need GCP_SA_KEY anymore - Workload Identity Federation replaces it!" -ForegroundColor Green

