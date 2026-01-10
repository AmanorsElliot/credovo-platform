# Cancel Cloud Build builds from a list of IDs in a file
# Useful when console shows builds but gcloud can't find them

param(
    [string]$BuildIdsFile = "build-ids.txt",
    [string]$ProjectId = "credovo-eu-apps-nonprod"
)

$ErrorActionPreference = "Stop"

Write-Host "=== Cancel Builds from File ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Project: $ProjectId" -ForegroundColor Gray
Write-Host "Build IDs file: $BuildIdsFile" -ForegroundColor Gray
Write-Host ""

if (-not (Test-Path $BuildIdsFile)) {
    Write-Host "[ERROR] File not found: $BuildIdsFile" -ForegroundColor Red
    Write-Host ""
    Write-Host "Create a file with build IDs (one per line):" -ForegroundColor Yellow
    Write-Host "  ebf9f559" -ForegroundColor Gray
    Write-Host "  b5757d0f" -ForegroundColor Gray
    Write-Host "  251cb093" -ForegroundColor Gray
    Write-Host "  ..." -ForegroundColor Gray
    Write-Host ""
    Write-Host "Or provide build IDs as comma-separated input:" -ForegroundColor Cyan
    $input = Read-Host "Enter build IDs (comma-separated)"
    if ([string]::IsNullOrEmpty($input)) {
        exit 0
    }
    $BuildIds = $input -split ',' | ForEach-Object { $_.Trim() }
} else {
    Write-Host "Reading build IDs from file..." -ForegroundColor Yellow
    $BuildIds = Get-Content $BuildIdsFile | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() }
}

if ($BuildIds.Count -eq 0) {
    Write-Host "No build IDs found." -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($BuildIds.Count) build ID(s) to cancel:" -ForegroundColor Yellow
Write-Host ""

# Show first 10 as preview
$previewCount = [Math]::Min(10, $BuildIds.Count)
for ($i = 0; $i -lt $previewCount; $i++) {
    Write-Host "  - $($BuildIds[$i])" -ForegroundColor Gray
}
if ($BuildIds.Count -gt 10) {
    Write-Host "  ... and $($BuildIds.Count - 10) more" -ForegroundColor Gray
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
$skipped = 0

foreach ($buildId in $BuildIds) {
    if ([string]::IsNullOrEmpty($buildId)) {
        continue
    }
    
    Write-Host "Cancelling build: $buildId..." -ForegroundColor Gray -NoNewline
    
    $result = gcloud builds cancel $buildId --project=$ProjectId --quiet 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host " [OK]" -ForegroundColor Green
        $cancelled++
    } else {
        # Check if already cancelled/completed
        $status = gcloud builds describe $buildId --format="value(status)" --project=$ProjectId 2>&1
        if ($status -in @("CANCELLED", "SUCCESS", "FAILURE", "TIMEOUT", "EXPIRED")) {
            Write-Host " [SKIP - already $status]" -ForegroundColor Yellow
            $skipped++
        } else {
            Write-Host " [FAIL]" -ForegroundColor Red
            Write-Host "     Error: $result" -ForegroundColor Gray
            $failed++
        }
    }
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "  [OK] Cancelled: $cancelled" -ForegroundColor Green
if ($skipped -gt 0) {
    Write-Host "  [SKIP] Already completed: $skipped" -ForegroundColor Yellow
}
if ($failed -gt 0) {
    Write-Host "  [FAIL] Failed: $failed" -ForegroundColor Red
}
Write-Host ""

if ($cancelled -gt 0) {
    Write-Host "Done! $cancelled build(s) have been cancelled." -ForegroundColor Green
} else {
    Write-Host "No builds were cancelled." -ForegroundColor Yellow
}

Write-Host ""

