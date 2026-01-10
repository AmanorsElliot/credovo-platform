# Cancel all Cloud Build builds (regardless of status)
# Useful when you have many builds to cancel

param(
    [string]$ProjectId = "credovo-eu-apps-nonprod",
    [int]$Limit = 500,
    [switch]$DryRun = $false
)

# Don't stop on errors - we'll handle them manually
$ErrorActionPreference = "Continue"

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
Write-Host "Querying builds with region=europe-west1..." -ForegroundColor Gray
$buildsData = gcloud builds list `
    --limit=$Limit `
    --region=europe-west1 `
    --format="json" `
    --project=$ProjectId 2>&1

$exitCode = $LASTEXITCODE

if ($exitCode -ne 0) {
    # Try without region
    Write-Host "Query with region failed, trying without region parameter..." -ForegroundColor Gray
    $buildsData = gcloud builds list `
        --limit=$Limit `
        --format="json" `
        --project=$ProjectId 2>&1
    $exitCode = $LASTEXITCODE
}

if ($exitCode -ne 0) {
    Write-Host "[ERROR] Error listing builds (exit code: $exitCode)" -ForegroundColor Red
    Write-Host "Error output: $buildsData" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Check if you have permission to list builds" -ForegroundColor White
    Write-Host "  2. Verify the project ID is correct: $ProjectId" -ForegroundColor White
    Write-Host "  3. Try manually: gcloud builds list --region=europe-west1 --project=$ProjectId" -ForegroundColor White
    exit 1
}

# Check if we got any data
if ([string]::IsNullOrWhiteSpace($buildsData)) {
    Write-Host "No builds found (empty response)." -ForegroundColor Green
    exit 0
}

# Parse JSON to get builds with status
Write-Host "Parsing build data..." -ForegroundColor Gray
try {
    $builds = $buildsData | ConvertFrom-Json
} catch {
    Write-Host "[ERROR] Failed to parse build data: $_" -ForegroundColor Red
    Write-Host "Raw data (first 500 chars): $($buildsData.Substring(0, [Math]::Min(500, $buildsData.Length)))" -ForegroundColor Gray
    exit 1
}

if (-not $builds) {
    Write-Host "No builds found (parsed result is null)." -ForegroundColor Green
    exit 0
}

# Handle both array and single object responses
if ($builds -isnot [Array]) {
    if ($builds.id) {
        $builds = @($builds)
        Write-Host "Found 1 build (converted to array)" -ForegroundColor Gray
    } else {
        Write-Host "No builds found (object has no id property)." -ForegroundColor Green
        exit 0
    }
}

if ($builds.Count -eq 0) {
    Write-Host "No builds found (array is empty)." -ForegroundColor Green
    exit 0
}

Write-Host "Found $($builds.Count) build(s) total" -ForegroundColor Green

# Filter out completed/failed builds (only cancel active ones)
Write-Host ""
Write-Host "Filtering for cancellable builds (QUEUED, WORKING, PENDING)..." -ForegroundColor Yellow

$cancellableBuilds = @()
$completedStatuses = @("SUCCESS", "FAILURE", "CANCELLED", "TIMEOUT", "EXPIRED")

# Count statuses for debugging
$statusCounts = @{}

foreach ($build in $builds) {
    if (-not $build.id) {
        continue
    }
    
    $status = $build.status
    if (-not $statusCounts.ContainsKey($status)) {
        $statusCounts[$status] = 0
    }
    $statusCounts[$status]++
    
    if ($status -notin $completedStatuses) {
        $cancellableBuilds += @{
            Id = $build.id
            Status = $status
            CreateTime = $build.createTime
        }
    }
}

Write-Host "Build status breakdown:" -ForegroundColor Gray
foreach ($status in $statusCounts.Keys | Sort-Object) {
    $count = $statusCounts[$status]
    $isCancellable = $status -notin $completedStatuses
    $marker = if ($isCancellable) { "[CANCELLABLE]" } else { "[COMPLETED]" }
    Write-Host "  $status : $count $marker" -ForegroundColor $(if ($isCancellable) { "Yellow" } else { "Gray" })
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
    
    # Suppress PowerShell error handling for this command
    # gcloud writes to stderr even on success, which PowerShell treats as an error
    $oldErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "SilentlyContinue"
    
    # Try with region first (required for regional builds)
    # Capture both stdout and stderr, but don't let PowerShell stop on errors
    $result = gcloud builds cancel $buildId --region=europe-west1 --project=$ProjectId --quiet 2>&1 | Out-String
    $cancelExitCode = $LASTEXITCODE
    
    if ($cancelExitCode -ne 0) {
        # Try without region (for global builds)
        $result = gcloud builds cancel $buildId --project=$ProjectId --quiet 2>&1 | Out-String
        $cancelExitCode = $LASTEXITCODE
    }
    
    # Restore error handling
    $ErrorActionPreference = $oldErrorAction
    
    $resultStr = $result.Trim()
    
    # Check for success - gcloud outputs "Cancelled" message even on success
    # Exit code 0 or "Cancelled [" in output means success
    if ($cancelExitCode -eq 0 -or $resultStr -match "Cancelled \[") {
        Write-Host " [OK]" -ForegroundColor Green
        $cancelled++
    } elseif ($resultStr -match "already.*CANCELLED|already.*SUCCESS|already.*FAILURE|NOT_FOUND|not found") {
        Write-Host " [SKIP - already completed or not found]" -ForegroundColor Yellow
        $skipped++
    } else {
        Write-Host " [FAIL]" -ForegroundColor Red
        Write-Host "     Error: $resultStr" -ForegroundColor Gray
        $failed++
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

