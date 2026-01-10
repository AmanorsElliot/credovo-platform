# Disable individual service triggers (by deleting them)
# Since we now have a parallel build trigger, individual triggers are redundant

param(
    [string]$ProjectId = "credovo-eu-apps-nonprod",
    [string]$Region = "europe-west1"
)

$ErrorActionPreference = "Stop"

Write-Host "=== Disabling Individual Service Triggers ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Since we have a parallel build trigger, individual triggers are redundant." -ForegroundColor Yellow
Write-Host "This script will DELETE the individual service triggers." -ForegroundColor Yellow
Write-Host ""

$triggers = @(
    "deploy-orchestration-service",
    "deploy-kyc-kyb-service",
    "deploy-connector-service"
)

foreach ($triggerName in $triggers) {
    Write-Host "Checking trigger: $triggerName..." -ForegroundColor Gray
    
    $exists = gcloud builds triggers list --region=$Region --project=$ProjectId --filter="name:$triggerName" --format="value(name)" 2>&1
    
    if ($exists) {
        Write-Host "  Deleting $triggerName..." -ForegroundColor Yellow
        $ErrorActionPreference = "Continue"
        $output = gcloud builds triggers delete $triggerName --region=$Region --project=$ProjectId --quiet 2>&1 | Out-String
        $ErrorActionPreference = "Stop"
        
        if ($LASTEXITCODE -eq 0 -or $output -match "Deleted") {
            Write-Host "  [OK] Deleted: $triggerName" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] Failed to delete: $triggerName" -ForegroundColor Red
        }
    } else {
        Write-Host "  WARNING Trigger not found: $triggerName" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "✅ Individual triggers removed" -ForegroundColor Green
Write-Host ""
Write-Host "Only the parallel trigger will run now:" -ForegroundColor Yellow
Write-Host "  • deploy-all-services-parallel" -ForegroundColor White
Write-Host ""
Write-Host "This will build all 3 services concurrently on each push to main." -ForegroundColor Gray
Write-Host ""

