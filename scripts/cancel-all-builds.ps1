# Cancel all Cloud Build builds (regardless of status)
# Useful when you have many builds to cancel

param(
    [string]$ProjectId = "credovo-eu-apps-nonprod",
    [int]$Limit = 100,
    [switch]$DryRun = $false
)

$ErrorActionPreference = "Stop"

Write-Host "=== Cancel All Cloud Build Builds ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Project: $ProjectId" -ForegroundColor Gray
Write-Host "Limit: $Limit builds" -ForegroundColor Gray
Write-Host ""

# Get all recent builds (not just QUEUED/WORKING)
Write-Host "Finding all recent builds..." -ForegroundColor Yellow

$allBuilds = gcloud builds list `
    --limit=$Limit `
    --format="table(id,status,createTime,source.repoSource.branchName)" `
    --project=$ProjectId 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Error listing builds: $allBuilds" -ForegroundColor Red
    exit 1
}

# Get all build IDs
$buildIds = gcloud builds list `
    --limit=$Limit `
    --format="value(id)" `
    --project=$ProjectId 2>&1

if (-not $buildIds -or $buildIds.Count -eq 0) {
    Write-Host "No builds found." -ForegroundColor Green
    exit 0
}

# Filter out completed/failed builds (only cancel active ones)
Write-Host ""
Write-Host "Filtering for cancellable builds (not SUCCESS, FAILURE, CANCELLED, TIMEOUT)..." -ForegroundColor Yellow

$cancellableBuilds = @()
foreach ($buildId in $buildIds) {
    if ([string]::IsNullOrEmpty($buildId)) {
        continue
    }
    
    $status = gcloud builds describe $buildId --format="value(status)" --project=$ProjectId 2>&1
    if ($LASTEXITCODE -eq 0) {
        if ($status -notin @("SUCCESS", "FAILURE", "CANCELLED", "TIMEOUT", "EXPIRED")) {
            $cancellableBuilds += $buildId
        }
    }
}

if ($cancellableBuilds.Count -eq 0) {
    Write-Host ""
    Write-Host "No cancellable builds found. All builds are already completed, failed, or cancelled." -ForegroundColor Green
    exit 0
}

Write-Host ""
Write-Host "Found $($cancellableBuilds.Count) build(s) that can be cancelled:" -ForegroundColor Yellow
Write-Host ""

# Show first 10 as preview
$previewCount = [Math]::Min(10, $cancellableBuilds.Count)
for ($i = 0; $i -lt $previewCount; $i++) {
    Write-Host "  - $($cancellableBuilds[$i])" -ForegroundColor Gray
}
if ($cancellableBuilds.Count -gt 10) {
    Write-Host "  ... and $($cancellableBuilds.Count - 10) more" -ForegroundColor Gray
}

Write-Host ""

if ($DryRun) {
    Write-Host "DRY RUN MODE - No builds will be cancelled" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To actually cancel these builds, run:" -ForegroundColor Cyan
    Write-Host "  .\scripts\cancel-all-builds.ps1" -ForegroundColor White
    exit 0
}

# Confirm cancellation
Write-Host "WARNING: This will cancel $($cancellableBuilds.Count) build(s)." -ForegroundColor Yellow
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

foreach ($buildId in $cancellableBuilds) {
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
    Write-Host ""
    Write-Host "New builds will trigger automatically on the next push." -ForegroundColor Gray
} else {
    Write-Host "No builds were cancelled." -ForegroundColor Yellow
}

Write-Host ""

