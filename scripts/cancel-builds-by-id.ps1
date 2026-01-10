# Cancel specific Cloud Build builds by their IDs
# Useful when console shows builds but gcloud filter doesn't find them

param(
    [string[]]$BuildIds = @(),
    [string]$ProjectId = "credovo-eu-apps-nonprod"
)

$ErrorActionPreference = "Stop"

Write-Host "=== Cancel Cloud Build Builds by ID ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Project: $ProjectId" -ForegroundColor Gray
Write-Host ""

if ($BuildIds.Count -eq 0) {
    Write-Host "Usage: .\scripts\cancel-builds-by-id.ps1 -BuildIds @('build-id-1', 'build-id-2')" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Or provide build IDs interactively:" -ForegroundColor Cyan
    Write-Host ""
    
    $input = Read-Host "Enter build IDs (comma-separated)"
    if ([string]::IsNullOrEmpty($input)) {
        Write-Host "No build IDs provided. Exiting." -ForegroundColor Yellow
        exit 0
    }
    
    $BuildIds = $input -split ',' | ForEach-Object { $_.Trim() }
}

Write-Host "Build IDs to cancel: $($BuildIds.Count)" -ForegroundColor Yellow
foreach ($id in $BuildIds) {
    Write-Host "  - $id" -ForegroundColor Gray
}
Write-Host ""

# Confirm cancellation
Write-Host "WARNING: This will cancel $($BuildIds.Count) build(s)." -ForegroundColor Yellow
$confirm = Read-Host "Continue? (y/N)"

if ($confirm -ne "y" -and $confirm -ne "Y") {
    Write-Host "Cancelled by user." -ForegroundColor Gray
    exit 0
}

Write-Host ""
Write-Host "Cancelling builds..." -ForegroundColor Yellow
Write-Host ""

$cancelled = 0
$failed = 0

foreach ($buildId in $BuildIds) {
    if ([string]::IsNullOrEmpty($buildId)) {
        continue
    }
    
    Write-Host "Cancelling build: $buildId..." -ForegroundColor Gray
    
    $result = gcloud builds cancel $buildId --project=$ProjectId --quiet 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Cancelled: $buildId" -ForegroundColor Green
        $cancelled++
    } else {
        Write-Host "  [FAIL] Failed to cancel: $buildId" -ForegroundColor Red
        Write-Host "     Error: $result" -ForegroundColor Gray
        $failed++
    }
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "  [OK] Cancelled: $cancelled" -ForegroundColor Green
if ($failed -gt 0) {
    Write-Host "  [FAIL] Failed: $failed" -ForegroundColor Red
}
Write-Host ""

if ($cancelled -gt 0) {
    Write-Host "Done! Builds have been cancelled." -ForegroundColor Green
} else {
    Write-Host "No builds were cancelled." -ForegroundColor Yellow
}

Write-Host ""

