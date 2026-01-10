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

# Get all recent builds with their statuses
# Try with region first, then without if that fails
Write-Host "Finding all recent builds..." -ForegroundColor Yellow

$buildsData = $null

# Try with region (europe-west1) first
$buildsData = gcloud builds list `
    --limit=$Limit `
    --region=europe-west1 `
    --format="json" `
    --project=$ProjectId 2>&1

if ($LASTEXITCODE -ne 0) {
    # Try without region
    Write-Host "Trying without region parameter..." -ForegroundColor Gray
    $buildsData = gcloud builds list `
        --limit=$Limit `
        --format="json" `
        --project=$ProjectId 2>&1
}

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Error listing builds: $buildsData" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Check if you have permission to list builds" -ForegroundColor White
    Write-Host "  2. Verify the project ID is correct: $ProjectId" -ForegroundColor White
    Write-Host "  3. Try manually: gcloud builds list --region=europe-west1 --project=$ProjectId" -ForegroundColor White
    exit 1
}

# Parse JSON to get builds with status
try {
    $builds = $buildsData | ConvertFrom-Json
} catch {
    Write-Host "[ERROR] Failed to parse build data: $_" -ForegroundColor Red
    Write-Host "Raw data: $buildsData" -ForegroundColor Gray
    exit 1
}

if (-not $builds) {
    Write-Host "No builds found." -ForegroundColor Green
    Write-Host ""
    Write-Host "Debug: Raw response was empty or invalid" -ForegroundColor Gray
    exit 0
}

# Handle both array and single object responses
if ($builds -isnot [Array]) {
    if ($builds.id) {
        $builds = @($builds)
    } else {
        Write-Host "No builds found." -ForegroundColor Green
        exit 0
    }
}

if ($builds.Count -eq 0) {
    Write-Host "No builds found." -ForegroundColor Green
    exit 0
}

if (-not $buildIds -or $buildIds.Count -eq 0) {
    Write-Host "No builds found." -ForegroundColor Green
    exit 0
}

# Filter out completed/failed builds (only cancel active ones)
Write-Host ""
Write-Host "Filtering for cancellable builds (QUEUED, WORKING, PENDING)..." -ForegroundColor Yellow

$cancellableBuilds = @()
$completedStatuses = @("SUCCESS", "FAILURE", "CANCELLED", "TIMEOUT", "EXPIRED")

foreach ($build in $builds) {
    if (-not $build.id) {
        continue
    }
    
    $status = $build.status
    if ($status -notin $completedStatuses) {
        $cancellableBuilds += @{
            Id = $build.id
            Status = $status
            CreateTime = $build.createTime
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
    $build = $cancellableBuilds[$i]
    Write-Host "  - $($build.Id) [$($build.Status)]" -ForegroundColor Gray
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

foreach ($build in $cancellableBuilds) {
    $buildId = $build.Id
    $currentStatus = $build.Status
    
    Write-Host "Cancelling build: $buildId [$currentStatus]..." -ForegroundColor Gray -NoNewline
    
    $result = gcloud builds cancel $buildId --project=$ProjectId --quiet 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host " [OK]" -ForegroundColor Green
        $cancelled++
    } else {
        # Check if already cancelled/completed (status might have changed)
        $resultStr = $result -join " "
        if ($resultStr -match "already.*CANCELLED|already.*SUCCESS|already.*FAILURE") {
            Write-Host " [SKIP - already completed]" -ForegroundColor Yellow
            $skipped++
        } else {
            Write-Host " [FAIL]" -ForegroundColor Red
            Write-Host "     Error: $resultStr" -ForegroundColor Gray
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

