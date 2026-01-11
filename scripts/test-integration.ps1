# Integration Test Suite for Credovo Platform
# Tests complete flows across services

param(
    [string]$OrchestrationUrl = "https://orchestration-service-saz24fo3sa-ew.a.run.app",
    [string]$AuthToken = "",
    [switch]$SkipWebhooks = $false,
    [switch]$SkipDataLake = $false
)

$ErrorActionPreference = "Stop"

Write-Host "=== Integration Test Suite ===" -ForegroundColor Cyan
Write-Host ""

# Test results
$script:TestResults = @{
    Passed = 0
    Failed = 0
    Tests = @()
}

function Add-TestResult {
    param(
        [string]$Name,
        [bool]$Passed,
        [string]$Message = ""
    )
    
    $result = @{
        Name = $Name
        Passed = $Passed
        Message = $Message
        Timestamp = Get-Date
    }
    
    $script:TestResults.Tests += $result
    
    if ($Passed) {
        $script:TestResults.Passed++
        Write-Host "  [OK] $Name" -ForegroundColor Green
        if ($Message) { Write-Host "      $Message" -ForegroundColor Gray }
    } else {
        $script:TestResults.Failed++
        Write-Host "  [FAIL] $Name" -ForegroundColor Red
        if ($Message) { Write-Host "      $Message" -ForegroundColor Red }
    }
}

# Get authentication token
if ([string]::IsNullOrEmpty($AuthToken)) {
    Write-Host "Getting authentication token..." -ForegroundColor Yellow
    
    # Try to get gcloud token
    $gcloudToken = $null
    try {
        $gcloudToken = gcloud auth print-identity-token --audiences=$OrchestrationUrl 2>&1
        if ($LASTEXITCODE -eq 0) {
            $AuthToken = $gcloudToken.Trim()
            Write-Host "  [OK] Using gcloud identity token" -ForegroundColor Green
        }
    } catch {
        Write-Host "  [WARN] Could not get gcloud token" -ForegroundColor Yellow
    }
    
    # Try to get backend JWT
    if ([string]::IsNullOrEmpty($AuthToken)) {
        try {
            $tokenScript = Join-Path $PSScriptRoot "get-test-token.ps1"
            if (Test-Path $tokenScript) {
                $AuthToken = & $tokenScript
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  [OK] Using backend JWT token" -ForegroundColor Green
                }
            }
        } catch {
            Write-Host "  [WARN] Could not get backend token" -ForegroundColor Yellow
        }
    }
}

$headers = @{
    "Content-Type" = "application/json"
}

if (-not [string]::IsNullOrEmpty($AuthToken)) {
    $headers["Authorization"] = "Bearer $AuthToken"
}

# Test 1: KYC Initiation Flow
Write-Host ""
Write-Host "1. KYC Initiation Flow" -ForegroundColor Yellow

$kycApplicationId = "integration-test-kyc-$(Get-Date -Format 'yyyyMMddHHmmss')"

try {
    $kycRequest = @{
        type = "individual"
        data = @{
            firstName = "Integration"
            lastName = "Test"
            dateOfBirth = "1990-01-01"
            email = "integration.test@example.com"
            country = "GB"
            address = @{
                line1 = "123 Test Street"
                city = "London"
                postcode = "SW1A 1AA"
                country = "GB"
            }
        }
    }

    $kycResponse = Invoke-RestMethod `
        -Uri "$OrchestrationUrl/api/v1/applications/$kycApplicationId/kyc/initiate" `
        -Method Post `
        -Headers $headers `
        -Body ($kycRequest | ConvertTo-Json -Depth 10) `
        -ErrorAction Stop

    Add-TestResult -Name "KYC Initiation" -Passed $true -Message "Status: $($kycResponse.status)"
    
    # Wait a bit for async processing
    Start-Sleep -Seconds 3
    
    # Check status
    try {
        $statusResponse = Invoke-RestMethod `
            -Uri "$OrchestrationUrl/api/v1/applications/$kycApplicationId/kyc/status" `
            -Method Get `
            -Headers $headers `
            -ErrorAction Stop
        
        Add-TestResult -Name "KYC Status Check" -Passed $true -Message "Status: $($statusResponse.status)"
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 404) {
            Add-TestResult -Name "KYC Status Check" -Passed $true -Message "Not found yet (normal for async)"
        } else {
            Add-TestResult -Name "KYC Status Check" -Passed $false -Message "Error: $($_.Exception.Message)"
        }
    }
} catch {
    Add-TestResult -Name "KYC Initiation" -Passed $false -Message $_.Exception.Message
}

# Test 2: KYB Initiation Flow
Write-Host ""
Write-Host "2. KYB Initiation Flow" -ForegroundColor Yellow

$kybApplicationId = "integration-test-kyb-$(Get-Date -Format 'yyyyMMddHHmmss')"

try {
    $kybRequest = @{
        companyNumber = "12345678"
        companyName = "Integration Test Company Ltd"
        country = "GB"
    }

    $kybResponse = Invoke-RestMethod `
        -Uri "$OrchestrationUrl/api/v1/applications/$kybApplicationId/kyb/verify" `
        -Method Post `
        -Headers $headers `
        -Body ($kybRequest | ConvertTo-Json -Depth 10) `
        -ErrorAction Stop

    Add-TestResult -Name "KYB Initiation" -Passed $true -Message "Status: $($kybResponse.status)"
    
    # Wait a bit for async processing
    Start-Sleep -Seconds 3
    
    # Check status
    try {
        $statusResponse = Invoke-RestMethod `
            -Uri "$OrchestrationUrl/api/v1/applications/$kybApplicationId/kyb/status" `
            -Method Get `
            -Headers $headers `
            -ErrorAction Stop
        
        Add-TestResult -Name "KYB Status Check" -Passed $true -Message "Status: $($statusResponse.status)"
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 404) {
            Add-TestResult -Name "KYB Status Check" -Passed $true -Message "Not found yet (normal for async)"
        } else {
            Add-TestResult -Name "KYB Status Check" -Passed $false -Message "Error: $($_.Exception.Message)"
        }
    }
} catch {
    Add-TestResult -Name "KYB Initiation" -Passed $false -Message $_.Exception.Message
}

# Test 3: Data Lake Verification
if (-not $SkipDataLake) {
    Write-Host ""
    Write-Host "3. Data Lake Storage Verification" -ForegroundColor Yellow
    
    try {
        $bucketName = "credovo-eu-apps-nonprod-data-lake-raw"
        $kycPath = "gs://$bucketName/kyc/requests/$kycApplicationId/"
        
        Start-Sleep -Seconds 5  # Wait for async storage
        
        $files = gsutil ls $kycPath 2>&1
        if ($LASTEXITCODE -eq 0) {
            Add-TestResult -Name "Data Lake KYC Storage" -Passed $true -Message "Files found"
        } else {
            Add-TestResult -Name "Data Lake KYC Storage" -Passed $false -Message "Files not found (may still be writing)"
        }
    } catch {
        Add-TestResult -Name "Data Lake Storage" -Passed $false -Message "Error: $($_.Exception.Message)"
    }
}

# Summary
Write-Host ""
Write-Host "=== Test Summary ===" -ForegroundColor Cyan
Write-Host "Total: $($script:TestResults.Tests.Count)" -ForegroundColor White
Write-Host "Passed: $($script:TestResults.Passed)" -ForegroundColor Green
Write-Host "Failed: $($script:TestResults.Failed)" -ForegroundColor $(if ($script:TestResults.Failed -eq 0) { "Green" } else { "Red" })
Write-Host ""

if ($script:TestResults.Failed -eq 0) {
    Write-Host "All integration tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "Some tests failed" -ForegroundColor Yellow
    exit 1
}
