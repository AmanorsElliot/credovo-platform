# Grant your user account access to invoke Cloud Run services
# This allows authenticated requests to work

param(
    [string]$ProjectId = "credovo-eu-apps-nonprod",
    [string]$Region = "europe-west1",
    [string]$UserEmail = ""
)

$ErrorActionPreference = "Stop"

Write-Host "=== Grant User Access to Cloud Run Services ===" -ForegroundColor Cyan
Write-Host ""

# Get current user email if not provided
if ([string]::IsNullOrEmpty($UserEmail)) {
    try {
        $gcloudAccount = gcloud config get-value account 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrEmpty($gcloudAccount)) {
            $UserEmail = $gcloudAccount
            Write-Host "Detected user: $UserEmail" -ForegroundColor Gray
        } else {
            Write-Host "⚠️  Could not detect user email" -ForegroundColor Yellow
            Write-Host "Please provide your email:" -ForegroundColor Yellow
            $UserEmail = Read-Host "Email"
        }
    } catch {
        Write-Host "⚠️  Could not detect user email" -ForegroundColor Yellow
        Write-Host "Please provide your email:" -ForegroundColor Yellow
        $UserEmail = Read-Host "Email"
    }
}

Write-Host "Project: $ProjectId" -ForegroundColor Gray
Write-Host "Region: $Region" -ForegroundColor Gray
Write-Host "User: $UserEmail" -ForegroundColor Gray
Write-Host ""

$services = @("orchestration-service", "kyc-kyb-service", "connector-service")

foreach ($service in $services) {
    Write-Host "Granting access to $service for $UserEmail..." -ForegroundColor Yellow
    
    try {
        gcloud run services add-iam-policy-binding $service `
            --region=$Region `
            --member="user:$UserEmail" `
            --role="roles/run.invoker" `
            --project=$ProjectId `
            --quiet
        
        Write-Host "  ✅ Access granted for $service" -ForegroundColor Green
    } catch {
        Write-Host "  ❌ Failed to grant access for $service" -ForegroundColor Red
        Write-Host "     Error: $($_.Exception.Message)" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "✅ Done! You can now make authenticated requests to Cloud Run services." -ForegroundColor Green
Write-Host ""
Write-Host "Test with:" -ForegroundColor Cyan
Write-Host "  .\scripts\test-comprehensive.ps1 -UseGcloudAuth" -ForegroundColor White
Write-Host ""

