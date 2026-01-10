# Comprehensive End-to-End Test Suite for Credovo Platform
# Tests KYC, KYB, webhooks, data lake, and status checks

param(
    [string]$OrchestrationUrl = "https://orchestration-service-saz24fo3sa-ew.a.run.app",
    [string]$AuthToken = "",
    [string]$ApplicationId = "test-$(Get-Date -Format 'yyyyMMddHHmmss')",
    [switch]$SkipWebhook = $false,
    [switch]$SkipDataLake = $false,
    [int]$StatusCheckRetries = 5,
    [int]$StatusCheckDelay = 5
)

$ErrorActionPreference = "Stop"

# Test results tracking
$script:TestResults = @{
    Passed = 0
    Failed = 0
    Skipped = 0
    Tests = @()
}

function Add-TestResult {
    param(
        [string]$Name,
        [bool]$Passed,
        [string]$Message = "",
        [bool]$Skipped = $false
    )
    
    $result = @{
        Name = $Name
        Passed = $Passed
        Message = $Message
        Skipped = $Skipped
        Timestamp = Get-Date
    }
    
    $script:TestResults.Tests += $result
    
    if ($Skipped) {
        $script:TestResults.Skipped++
        Write-Host "   ⏭️  SKIPPED: $Name" -ForegroundColor Yellow
        if ($Message) { Write-Host "      $Message" -ForegroundColor Gray }
    } elseif ($Passed) {
        $script:TestResults.Passed++
        Write-Host "   ✅ PASSED: $Name" -ForegroundColor Green
        if ($Message) { Write-Host "      $Message" -ForegroundColor Gray }
    } else {
        $script:TestResults.Failed++
        Write-Host "   ❌ FAILED: $Name" -ForegroundColor Red
        if ($Message) { Write-Host "      $Message" -ForegroundColor Red }
    }
}

Write-Host "=== Comprehensive Credovo Platform Test Suite ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Orchestration URL: $OrchestrationUrl" -ForegroundColor Gray
Write-Host "  Application ID: $ApplicationId" -ForegroundColor Gray
Write-Host "  Status Check Retries: $StatusCheckRetries" -ForegroundColor Gray
Write-Host "  Status Check Delay: $StatusCheckDelay seconds" -ForegroundColor Gray
Write-Host ""

# Setup headers
$headers = @{
    "Content-Type" = "application/json"
}

if (-not [string]::IsNullOrEmpty($AuthToken)) {
    $headers["Authorization"] = "Bearer $AuthToken"
    Add-TestResult -Name "Auth Token Provided" -Passed $true
} else {
    Add-TestResult -Name "Auth Token Provided" -Passed $false -Message "No auth token - some tests may fail"
}

Write-Host "=== Test Suite Execution ===" -ForegroundColor Cyan
Write-Host ""

# Test 1: Health Checks
Write-Host "1. Health Checks" -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "$OrchestrationUrl/health" -Method Get -ErrorAction Stop
    Add-TestResult -Name "Orchestration Service Health" -Passed $true -Message "Status: $($health.status)"
} catch {
    Add-TestResult -Name "Orchestration Service Health" -Passed $false -Message $_.Exception.Message
    Write-Host "   ⚠️  Cannot continue without healthy service" -ForegroundColor Red
    exit 1
}

# Test 2: KYC Initiation
Write-Host ""
Write-Host "2. KYC Verification Flow" -ForegroundColor Yellow

$kycRequest = @{
    type = "individual"
    data = @{
        firstName = "John"
        lastName = "Doe"
        dateOfBirth = "1990-01-01"
        email = "john.doe.test@example.com"
        country = "GB"
        address = @{
            line1 = "123 Test Street"
            city = "London"
            postcode = "SW1A 1AA"
            country = "GB"
        }
    }
}

try {
    $kycResponse = Invoke-RestMethod `
        -Uri "$OrchestrationUrl/api/v1/applications/$ApplicationId/kyc/initiate" `
        -Method Post `
        -Headers $headers `
        -Body ($kycRequest | ConvertTo-Json -Depth 10) `
        -ErrorAction Stop
    
    Add-TestResult -Name "KYC Initiation" -Passed $true -Message "Status: $($kycResponse.status), Provider: $($kycResponse.provider)"
    $kycReference = $kycResponse.result?.metadata?.reference
} catch {
    Add-TestResult -Name "KYC Initiation" -Passed $false -Message $_.Exception.Message
    $kycReference = $null
}

# Test 3: KYC Status Check (with retries)
if ($kycReference) {
    Write-Host ""
    Write-Host "3. KYC Status Check (Polling)" -ForegroundColor Yellow
    
    $statusFound = $false
    for ($i = 1; $i -le $StatusCheckRetries; $i++) {
        Write-Host "   Attempt $i/$StatusCheckRetries..." -ForegroundColor Gray
        Start-Sleep -Seconds $StatusCheckDelay
        
        try {
            $statusResponse = Invoke-RestMethod `
                -Uri "$OrchestrationUrl/api/v1/applications/$ApplicationId/kyc/status" `
                -Method Get `
                -Headers $headers `
                -ErrorAction Stop
            
            if ($statusResponse.status -and $statusResponse.status -ne 'pending') {
                Add-TestResult -Name "KYC Status Retrieved" -Passed $true -Message "Status: $($statusResponse.status)"
                if ($statusResponse.result?.aml) {
                    Add-TestResult -Name "AML Results Included" -Passed $true -Message "AML screening completed"
                }
                $statusFound = $true
                break
            } else {
                Write-Host "      Status: $($statusResponse.status) (still processing...)" -ForegroundColor Gray
            }
        } catch {
            if ($_.Exception.Response.StatusCode -eq 404) {
                Write-Host "      Status not found yet (normal for async processing)" -ForegroundColor Gray
            } else {
                Write-Host "      Error: $($_.Exception.Message)" -ForegroundColor Gray
            }
        }
    }
    
    if (-not $statusFound) {
        Add-TestResult -Name "KYC Status Retrieved" -Passed $false -Message "Status not available after $StatusCheckRetries attempts (may still be processing)"
    }
}

# Test 4: KYB Initiation
Write-Host ""
Write-Host "4. KYB Verification Flow" -ForegroundColor Yellow

$kybRequest = @{
    companyNumber = "12345678"
    companyName = "Test Company Ltd"
    country = "GB"
    email = "company.test@example.com"
}

try {
    $kybResponse = Invoke-RestMethod `
        -Uri "$OrchestrationUrl/api/v1/applications/$ApplicationId/kyb/verify" `
        -Method Post `
        -Headers $headers `
        -Body ($kybRequest | ConvertTo-Json -Depth 10) `
        -ErrorAction Stop
    
    Add-TestResult -Name "KYB Initiation" -Passed $true -Message "Status: $($kybResponse.status)"
    $kybReference = $kybResponse.data?.reference
} catch {
    Add-TestResult -Name "KYB Initiation" -Passed $false -Message $_.Exception.Message
    $kybReference = $null
}

# Test 5: Webhook Endpoint Health
Write-Host ""
Write-Host "5. Webhook Endpoint" -ForegroundColor Yellow

if (-not $SkipWebhook) {
    try {
        $webhookHealth = Invoke-RestMethod `
            -Uri "$OrchestrationUrl/api/v1/webhooks/health" `
            -Method Get `
            -ErrorAction Stop
        
        Add-TestResult -Name "Webhook Endpoint Health" -Passed $true -Message "Status: $($webhookHealth.status)"
    } catch {
        Add-TestResult -Name "Webhook Endpoint Health" -Passed $false -Message $_.Exception.Message
    }
} else {
    Add-TestResult -Name "Webhook Endpoint Health" -Skipped $true -Message "Skipped by user"
}

# Test 6: Data Lake Verification (if gcloud is available)
Write-Host ""
Write-Host "6. Data Lake Storage Verification" -ForegroundColor Yellow

if (-not $SkipDataLake) {
    try {
        $gcloudCheck = Get-Command gcloud -ErrorAction Stop
        $bucketName = "credovo-eu-apps-nonprod-data-lake-raw"
        
        Write-Host "   Checking GCS bucket: $bucketName" -ForegroundColor Gray
        
        $kycPath = "gs://$bucketName/kyc/requests/$ApplicationId/"
        $kybPath = "gs://$bucketName/kyb/requests/$ApplicationId/"
        
        # Check if files exist (this may take a moment for async writes)
        Start-Sleep -Seconds 3
        
        $kycFiles = gsutil ls $kycPath 2>&1
        if ($LASTEXITCODE -eq 0) {
            Add-TestResult -Name "KYC Data Lake Storage" -Passed $true -Message "Files found in data lake"
        } else {
            Add-TestResult -Name "KYC Data Lake Storage" -Passed $false -Message "Files not found (may still be writing)"
        }
        
        $kybFiles = gsutil ls $kybPath 2>&1
        if ($LASTEXITCODE -eq 0) {
            Add-TestResult -Name "KYB Data Lake Storage" -Passed $true -Message "Files found in data lake"
        } else {
            Add-TestResult -Name "KYB Data Lake Storage" -Passed $false -Message "Files not found (may still be writing)"
        }
    } catch {
        Add-TestResult -Name "Data Lake Storage Check" -Skipped $true -Message "gcloud not available or not authenticated"
    }
} else {
    Add-TestResult -Name "Data Lake Storage Check" -Skipped $true -Message "Skipped by user"
}

# Test 7: Error Handling
Write-Host ""
Write-Host "7. Error Handling Tests" -ForegroundColor Yellow

# Test invalid application ID
try {
    $invalidResponse = Invoke-RestMethod `
        -Uri "$OrchestrationUrl/api/v1/applications/invalid-id-12345/kyc/status" `
        -Method Get `
        -Headers $headers `
        -ErrorAction Stop
    
    Add-TestResult -Name "Invalid Application ID Handling" -Passed $false -Message "Should return 404 for invalid ID"
} catch {
    if ($_.Exception.Response.StatusCode -eq 404) {
        Add-TestResult -Name "Invalid Application ID Handling" -Passed $true -Message "Correctly returns 404"
    } else {
        Add-TestResult -Name "Invalid Application ID Handling" -Passed $false -Message "Unexpected error: $($_.Exception.Message)"
    }
}

# Test Summary
Write-Host ""
Write-Host "=== Test Summary ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total Tests: $($script:TestResults.Tests.Count)" -ForegroundColor White
Write-Host "  ✅ Passed: $($script:TestResults.Passed)" -ForegroundColor Green
Write-Host "  ❌ Failed: $($script:TestResults.Failed)" -ForegroundColor Red
Write-Host "  ⏭️  Skipped: $($script:TestResults.Skipped)" -ForegroundColor Yellow
Write-Host ""

$passRate = if ($script:TestResults.Tests.Count -gt 0) {
    [math]::Round(($script:TestResults.Passed / ($script:TestResults.Tests.Count - $script:TestResults.Skipped)) * 100, 1)
} else { 0 }

Write-Host "Pass Rate: $passRate%" -ForegroundColor $(if ($passRate -ge 80) { "Green" } elseif ($passRate -ge 50) { "Yellow" } else { "Red" })
Write-Host ""

if ($script:TestResults.Failed -eq 0) {
    Write-Host "🎉 All tests passed!" -ForegroundColor Green
} else {
    Write-Host "⚠️  Some tests failed - review output above" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Check Cloud Run logs for webhook callbacks" -ForegroundColor White
Write-Host "  2. Verify data lake storage (may take a few minutes)" -ForegroundColor White
Write-Host "  3. Check monitoring dashboards for metrics" -ForegroundColor White
Write-Host "  4. Review test results above for any failures" -ForegroundColor White
Write-Host ""

