# Fix gcloud authentication and permissions
# This script helps resolve the "iam.serviceAccounts.getAccessToken" permission error

param(
    [string]$ProjectId = "credovo-eu-apps-nonprod",
    [string]$UserEmail = "elliot@amanors.com"
)

Write-Host "=== Fixing gcloud Authentication ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Re-authenticate
Write-Host "Step 1: Re-authenticating gcloud..." -ForegroundColor Yellow
Write-Host "Please run this command manually in your terminal:" -ForegroundColor Cyan
Write-Host "  gcloud auth login" -ForegroundColor Green
Write-Host ""
Write-Host "Press Enter after you've run the command, or Ctrl+C to cancel..." -ForegroundColor Yellow
Read-Host

# Step 2: Grant project-level permission to create service account tokens
Write-Host ""
Write-Host "Step 2: Granting project-level service account token creator permission..." -ForegroundColor Yellow
Write-Host "This allows you to impersonate service accounts when needed." -ForegroundColor Gray
Write-Host ""

# Grant the role at project level (allows impersonating any service account in the project)
gcloud projects add-iam-policy-binding $ProjectId `
    --member="user:$UserEmail" `
    --role="roles/iam.serviceAccountTokenCreator" `
    --condition=None 2>&1 | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Project-level permission granted" -ForegroundColor Green
} else {
    Write-Host "⚠️  Permission may already be granted or you may not have permission to grant it" -ForegroundColor Yellow
}

# Step 3: Test authentication
Write-Host ""
Write-Host "Step 3: Testing authentication..." -ForegroundColor Yellow
$testResult = gcloud projects describe $ProjectId 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Authentication successful!" -ForegroundColor Green
    Write-Host ""
    Write-Host "You can now run gcloud commands without permission errors." -ForegroundColor Green
} else {
    Write-Host "❌ Authentication still failing" -ForegroundColor Red
    Write-Host ""
    Write-Host "Try running:" -ForegroundColor Yellow
    Write-Host "  gcloud auth application-default login" -ForegroundColor Green
    Write-Host ""
    Write-Host "Or check if you need to grant yourself additional permissions." -ForegroundColor Yellow
}

