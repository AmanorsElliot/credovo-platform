# Cancel all stuck/scheduled Cloud Build builds
# Useful when builds are stuck in "scheduled" or "queued" status

param(
    [string]$ProjectId = "credovo-eu-apps-nonprod",
    [string]$Region = "europe-west1",
    [switch]$DryRun = $false
)

$ErrorActionPreference = "Stop"

Write-Host "=== Cancel Stuck Cloud Build Builds ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Project: $ProjectId" -ForegroundColor Gray
Write-Host ""

# Find all builds in QUEUED, WORKING, or PENDING status
# Note: Console may show "scheduled" but API uses different status names
Write-Host "Finding scheduled/queued builds..." -ForegroundColor Yellow
Write-Host "(Checking QUEUED, WORKING, and PENDING statuses)" -ForegroundColor Gray
Write-Host ""

# Try with region first (required for regional builds)
Write-Host "Querying builds with region=$Region..." -ForegroundColor Gray
$builds = gcloud builds list `
    --region=$Region `
    --filter="status=QUEUED OR status=WORKING OR status=PENDING" `
    --format="table(id,status,createTime,substitutions._SERVICE_NAME)" `
    --project=$ProjectId 2>&1

if ($LASTEXITCODE -ne 0) {
    # Try without region as fallback
    Write-Host "Trying without region parameter..." -ForegroundColor Gray
    $builds = gcloud builds list `
        --filter="status=QUEUED OR status=WORKING OR status=PENDING" `
        --format="table(id,status,createTime,substitutions._SERVICE_NAME)" `
        --project=$ProjectId 2>&1
}

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Error listing builds: $builds" -ForegroundColor Red
    exit 1
}

# Parse build IDs (try with region first)
$buildIds = gcloud builds list `
    --region=$Region `
    --filter="status=QUEUED OR status=WORKING OR status=PENDING" `
    --format="value(id)" `
    --project=$ProjectId 2>&1

if ($LASTEXITCODE -ne 0) {
    # Try without region as fallback
    $buildIds = gcloud builds list `
        --filter="status=QUEUED OR status=WORKING OR status=PENDING" `
        --format="value(id)" `
        --project=$ProjectId 2>&1
}

if (-not $buildIds -or $buildIds.Count -eq 0) {
    Write-Host "No scheduled or queued builds found." -ForegroundColor Green
    Write-Host ""
    Write-Host "All builds are either completed or failed." -ForegroundColor Gray
    exit 0
}

Write-Host ""
Write-Host "Found $($buildIds.Count) build(s) to cancel:" -ForegroundColor Yellow
Write-Host ""
Write-Host $builds -ForegroundColor Gray
Write-Host ""

if ($DryRun) {
    Write-Host "DRY RUN MODE - No builds will be cancelled" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To actually cancel these builds, run:" -ForegroundColor Cyan
    Write-Host "  .\scripts\cancel-stuck-builds.ps1" -ForegroundColor White
    exit 0
}

# Confirm cancellation
Write-Host "WARNING: This will cancel $($buildIds.Count) build(s)." -ForegroundColor Yellow
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

foreach ($buildId in $buildIds) {
    if ([string]::IsNullOrEmpty($buildId)) {
        continue
    }
    
    Write-Host "Cancelling build: $buildId..." -ForegroundColor Gray
    
    # Try with region first (required for regional builds)
    $result = gcloud builds cancel $buildId --region=$Region --project=$ProjectId --quiet 2>&1
    $cancelExitCode = $LASTEXITCODE
    
    if ($cancelExitCode -ne 0) {
        # Try without region (for global builds)
        $result = gcloud builds cancel $buildId --project=$ProjectId --quiet 2>&1
        $cancelExitCode = $LASTEXITCODE
    }
    
    # Check for success - gcloud outputs "Cancelled" message even on success
    if ($cancelExitCode -eq 0 -or $result -match "Cancelled \[") {
        Write-Host "  [OK] Cancelled: $buildId" -ForegroundColor Green
        $cancelled++
    } elseif ($result -match "already.*CANCELLED|already.*SUCCESS|already.*FAILURE|NOT_FOUND") {
        Write-Host "  [SKIP - already completed or not found]" -ForegroundColor Yellow
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
    Write-Host ""
    Write-Host "New builds will trigger automatically on the next push." -ForegroundColor Gray
} else {
    Write-Host "No builds were cancelled." -ForegroundColor Yellow
}

Write-Host ""

