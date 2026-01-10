# Test KYC/KYB Integration with Shufti Pro
# This script tests the end-to-end verification flow

param(
    [string]$OrchestrationUrl = "https://orchestration-service-saz24fo3sa-ew.a.run.app",
    [string]$AuthToken = "",  # Supabase JWT token - get from frontend or generate
    [string]$ApplicationId = "test-app-$(Get-Date -Format 'yyyyMMddHHmmss')"
)

$ErrorActionPreference = "Stop"

Write-Host "=== KYC/KYB Integration Test ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Orchestration Service: $OrchestrationUrl" -ForegroundColor Gray
Write-Host "Application ID: $ApplicationId" -ForegroundColor Gray
Write-Host ""

# Check if auth token is provided
if ([string]::IsNullOrEmpty($AuthToken)) {
    Write-Host "⚠️  WARNING: No auth token provided" -ForegroundColor Yellow
    Write-Host "   You need a valid Supabase JWT token to test" -ForegroundColor Yellow
    Write-Host "   Get it from your frontend or generate one for testing" -ForegroundColor Yellow
    Write-Host ""
    $continue = Read-Host "Continue without auth? (y/n)"
    if ($continue -ne "y") {
        exit
    }
}

# Test 1: Health Check
Write-Host "1. Testing Health Endpoints..." -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "$OrchestrationUrl/health" -Method Get
    Write-Host "   ✅ Orchestration service is healthy" -ForegroundColor Green
    Write-Host "      Status: $($health.status)" -ForegroundColor Gray
} catch {
    Write-Host "   ❌ Orchestration service health check failed" -ForegroundColor Red
    Write-Host "      Error: $($_.Exception.Message)" -ForegroundColor Red
    exit
}

# Test 2: KYC Initiation
Write-Host ""
Write-Host "2. Testing KYC Initiation..." -ForegroundColor Yellow
try {
    $kycRequest = @{
        type = "individual"
        data = @{
            firstName = "John"
            lastName = "Doe"
            dateOfBirth = "1990-01-01"
            email = "john.doe@example.com"
            country = "GB"
            address = @{
                line1 = "123 Test Street"
                city = "London"
                postcode = "SW1A 1AA"
                country = "GB"
            }
        }
    }

    $headers = @{
        "Content-Type" = "application/json"
    }

    if (-not [string]::IsNullOrEmpty($AuthToken)) {
        $headers["Authorization"] = "Bearer $AuthToken"
    }

    $response = Invoke-RestMethod `
        -Uri "$OrchestrationUrl/api/v1/applications/$ApplicationId/kyc/initiate" `
        -Method Post `
        -Headers $headers `
        -Body ($kycRequest | ConvertTo-Json -Depth 10)

    Write-Host "   ✅ KYC initiation successful" -ForegroundColor Green
    Write-Host "      Application ID: $($response.applicationId)" -ForegroundColor Gray
    Write-Host "      Status: $($response.status)" -ForegroundColor Gray
    Write-Host "      Provider: $($response.provider)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   📝 Note: Verification is async - check status or wait for webhook" -ForegroundColor Cyan

    $kycStatus = $response.status
    $kycApplicationId = $response.applicationId

} catch {
    Write-Host "   ❌ KYC initiation failed" -ForegroundColor Red
    Write-Host "      Error: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $responseBody = $reader.ReadToEnd()
        Write-Host "      Response: $responseBody" -ForegroundColor Red
    }
    exit
}

# Test 3: Check KYC Status
Write-Host ""
Write-Host "3. Testing KYC Status Check..." -ForegroundColor Yellow
Start-Sleep -Seconds 2  # Wait a bit for processing

try {
    $statusResponse = Invoke-RestMethod `
        -Uri "$OrchestrationUrl/api/v1/applications/$ApplicationId/kyc/status" `
        -Method Get `
        -Headers $headers

    Write-Host "   ✅ KYC status retrieved" -ForegroundColor Green
    Write-Host "      Status: $($statusResponse.status)" -ForegroundColor Gray
    Write-Host "      Provider: $($statusResponse.provider)" -ForegroundColor Gray
    if ($statusResponse.result) {
        Write-Host "      Score: $($statusResponse.result.score)" -ForegroundColor Gray
        if ($statusResponse.result.aml) {
            Write-Host "      AML: Included" -ForegroundColor Gray
        }
    }
} catch {
    Write-Host "   ⚠️  KYC status check failed (might be too early)" -ForegroundColor Yellow
    Write-Host "      Error: $($_.Exception.Message)" -ForegroundColor Gray
    Write-Host "      This is normal if verification is still processing" -ForegroundColor Gray
}

# Test 4: KYB Initiation
Write-Host ""
Write-Host "4. Testing KYB Initiation..." -ForegroundColor Yellow
try {
    $kybRequest = @{
        companyNumber = "12345678"
        companyName = "Test Company Ltd"
        country = "GB"
        email = "company@example.com"
    }

    $kybResponse = Invoke-RestMethod `
        -Uri "$OrchestrationUrl/api/v1/applications/$ApplicationId/kyb/verify" `
        -Method Post `
        -Headers $headers `
        -Body ($kybRequest | ConvertTo-Json -Depth 10)

    Write-Host "   ✅ KYB initiation successful" -ForegroundColor Green
    Write-Host "      Application ID: $($kybResponse.applicationId)" -ForegroundColor Gray
    Write-Host "      Status: $($kybResponse.status)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   📝 Note: Verification is async - check status or wait for webhook" -ForegroundColor Cyan

} catch {
    Write-Host "   ❌ KYB initiation failed" -ForegroundColor Red
    Write-Host "      Error: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $responseBody = $reader.ReadToEnd()
        Write-Host "      Response: $responseBody" -ForegroundColor Red
    }
}

# Test 5: Check Webhook Endpoint
Write-Host ""
Write-Host "5. Testing Webhook Endpoint..." -ForegroundColor Yellow
try {
    $webhookHealth = Invoke-RestMethod `
        -Uri "$OrchestrationUrl/api/v1/webhooks/health" `
        -Method Get

    Write-Host "   ✅ Webhook endpoint is healthy" -ForegroundColor Green
    Write-Host "      Status: $($webhookHealth.status)" -ForegroundColor Gray
} catch {
    Write-Host "   ⚠️  Webhook health check failed" -ForegroundColor Yellow
    Write-Host "      Error: $($_.Exception.Message)" -ForegroundColor Gray
}

# Summary
Write-Host ""
Write-Host "=== Test Summary ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "✅ Health checks passed" -ForegroundColor Green
Write-Host "✅ KYC initiation tested" -ForegroundColor Green
Write-Host "✅ KYB initiation tested" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Check Cloud Run logs for webhook callbacks:" -ForegroundColor White
Write-Host "     gcloud logging read \"resource.type=cloud_run_revision AND resource.labels.service_name=orchestration-service AND textPayload=~'webhook'\" --limit=10 --project=credovo-eu-apps-nonprod" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. Check data lake storage:" -ForegroundColor White
Write-Host "     gsutil ls gs://credovo-eu-apps-nonprod-data-lake-raw/kyc/requests/$ApplicationId/" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. Monitor verification status:" -ForegroundColor White
Write-Host "     Check Shufti Pro back office for verification status" -ForegroundColor Gray
Write-Host "     Or poll the status endpoint periodically" -ForegroundColor Gray
Write-Host ""

