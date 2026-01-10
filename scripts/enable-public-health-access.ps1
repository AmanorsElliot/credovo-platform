# Enable public access to health endpoints for Cloud Run services
# This allows unauthenticated access to /health endpoints for monitoring

param(
    [string]$ProjectId = "credovo-eu-apps-nonprod",
    [string]$Region = "europe-west1"
)

$ErrorActionPreference = "Stop"

Write-Host "=== Enable Public Access to Health Endpoints ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "This will allow unauthenticated access to Cloud Run services" -ForegroundColor Yellow
Write-Host "for health checks and monitoring." -ForegroundColor Yellow
Write-Host ""
Write-Host "Project: $ProjectId" -ForegroundColor Gray
Write-Host "Region: $Region" -ForegroundColor Gray
Write-Host ""

$services = @("orchestration-service", "kyc-kyb-service", "connector-service")

foreach ($service in $services) {
    Write-Host "Enabling public access for $service..." -ForegroundColor Yellow
    
    try {
        gcloud run services add-iam-policy-binding $service `
            --region=$Region `
            --member="allUsers" `
            --role="roles/run.invoker" `
            --project=$ProjectId `
            --quiet
        
        Write-Host "  ✅ Public access enabled for $service" -ForegroundColor Green
    } catch {
        Write-Host "  ⚠️  Failed to enable public access for $service" -ForegroundColor Yellow
        Write-Host "     Error: $($_.Exception.Message)" -ForegroundColor Gray
        Write-Host "     This may be blocked by organization policies" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "=== Alternative: Use Authenticated Requests ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "If public access is blocked, use authenticated requests:" -ForegroundColor Yellow
Write-Host "  1. Authenticate with gcloud: gcloud auth login" -ForegroundColor White
Write-Host "  2. Use token in requests (already supported in test script)" -ForegroundColor White
Write-Host ""

