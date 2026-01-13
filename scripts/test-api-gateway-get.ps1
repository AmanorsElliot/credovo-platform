# Test API Gateway GET Requests
# This script tests GET requests to API Gateway to verify if the optional parameters fix works

param(
    [string]$ProjectId = "credovo-eu-apps-nonprod",
    [string]$Region = "europe-west1",
    [Parameter(Mandatory=$false)]
    [string]$SupabaseToken = ""
)

Write-Host "Testing API Gateway GET Requests..." -ForegroundColor Green
Write-Host ""

# Get API Gateway URL
Write-Host "Step 1: Getting API Gateway URL..." -ForegroundColor Yellow
$gatewayUrl = gcloud api-gateway gateways describe proxy-gateway `
    --location=$Region `
    --project=$ProjectId `
    --format="value(defaultHostname)" `
    2>&1

if ($LASTEXITCODE -ne 0 -or -not $gatewayUrl) {
    Write-Host "ERROR: Could not get API Gateway URL" -ForegroundColor Red
    Write-Host "Make sure API Gateway is deployed: .\scripts\deploy-api-gateway.ps1" -ForegroundColor Yellow
    exit 1
}

$fullGatewayUrl = "https://$gatewayUrl"
Write-Host "API Gateway URL: $fullGatewayUrl" -ForegroundColor Cyan
Write-Host ""

# Get Supabase token if not provided
if ([string]::IsNullOrEmpty($SupabaseToken)) {
    Write-Host "Step 2: Getting Supabase JWT token..." -ForegroundColor Yellow
    Write-Host "Please provide your Supabase JWT token (or press Enter to skip token tests):" -ForegroundColor Yellow
    $SupabaseToken = Read-Host "Supabase JWT Token"
    
    if ([string]::IsNullOrEmpty($SupabaseToken)) {
        Write-Host "No token provided - will test without authentication" -ForegroundColor Yellow
        Write-Host ""
    }
}

# Test 1: Health check (no auth required)
Write-Host "Test 1: GET /api/v1/health (no auth)" -ForegroundColor Cyan
Write-Host "URL: $fullGatewayUrl/api/v1/health" -ForegroundColor Gray
try {
    $response = Invoke-WebRequest -Uri "$fullGatewayUrl/api/v1/health" `
        -Method GET `
        -UseBasicParsing `
        -ErrorAction Stop
    
    Write-Host "✅ Status: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "Response: $($response.Content)" -ForegroundColor Gray
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        $statusCode = $_.Exception.Response.StatusCode.value__
        Write-Host "Status Code: $statusCode" -ForegroundColor Red
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $responseBody = $reader.ReadToEnd()
        Write-Host "Response: $responseBody" -ForegroundColor Red
    }
}
Write-Host ""

# Test 2: Company search (with auth if token provided)
if (-not [string]::IsNullOrEmpty($SupabaseToken)) {
    Write-Host "Test 2: GET /api/v1/companies/search?query=test&limit=10 (with auth)" -ForegroundColor Cyan
    Write-Host "URL: $fullGatewayUrl/api/v1/companies/search?query=test&limit=10" -ForegroundColor Gray
    try {
        $response = Invoke-WebRequest -Uri "$fullGatewayUrl/api/v1/companies/search?query=test&limit=10" `
            -Method GET `
            -Headers @{
                "X-Supabase-Token" = $SupabaseToken
            } `
            -UseBasicParsing `
            -ErrorAction Stop
        
        Write-Host "✅ Status: $($response.StatusCode)" -ForegroundColor Green
        $jsonResponse = $response.Content | ConvertFrom-Json
        Write-Host "Companies found: $($jsonResponse.companies.Count)" -ForegroundColor Green
        Write-Host "Response preview: $($response.Content.Substring(0, [Math]::Min(200, $response.Content.Length)))..." -ForegroundColor Gray
    } catch {
        Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.Exception.Response) {
            $statusCode = $_.Exception.Response.StatusCode.value__
            Write-Host "Status Code: $statusCode" -ForegroundColor Red
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $responseBody = $reader.ReadToEnd()
            if ($responseBody.Length -gt 500) {
                Write-Host "Response (first 500 chars): $($responseBody.Substring(0, 500))..." -ForegroundColor Red
            } else {
                Write-Host "Response: $responseBody" -ForegroundColor Red
            }
            
            # Check if it's the Google HTML 400 error
            if ($responseBody -match "<title>Error 400") {
                Write-Host "`n⚠️  This is the Google HTML 400 error - API Gateway is rejecting the request" -ForegroundColor Yellow
                Write-Host "This means the optional parameters fix did NOT work." -ForegroundColor Yellow
            }
        }
    }
    Write-Host ""
    
    # Test 3: Applications list
    Write-Host "Test 3: GET /api/v1/applications (with auth)" -ForegroundColor Cyan
    Write-Host "URL: $fullGatewayUrl/api/v1/applications" -ForegroundColor Gray
    try {
        $response = Invoke-WebRequest -Uri "$fullGatewayUrl/api/v1/applications" `
            -Method GET `
            -Headers @{
                "X-Supabase-Token" = $SupabaseToken
            } `
            -UseBasicParsing `
            -ErrorAction Stop
        
        Write-Host "✅ Status: $($response.StatusCode)" -ForegroundColor Green
        Write-Host "Response preview: $($response.Content.Substring(0, [Math]::Min(200, $response.Content.Length)))..." -ForegroundColor Gray
    } catch {
        Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.Exception.Response) {
            $statusCode = $_.Exception.Response.StatusCode.value__
            Write-Host "Status Code: $statusCode" -ForegroundColor Red
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $responseBody = $reader.ReadToEnd()
            if ($responseBody.Length -gt 500) {
                Write-Host "Response (first 500 chars): $($responseBody.Substring(0, 500))..." -ForegroundColor Red
            } else {
                Write-Host "Response: $responseBody" -ForegroundColor Red
            }
            
            if ($responseBody -match "<title>Error 400") {
                Write-Host "`n⚠️  This is the Google HTML 400 error - API Gateway is rejecting the request" -ForegroundColor Yellow
            }
        }
    }
    Write-Host ""
} else {
    Write-Host "Test 2 & 3: Skipped (no token provided)" -ForegroundColor Yellow
    Write-Host "To test authenticated endpoints, run:" -ForegroundColor Yellow
    Write-Host "  .\scripts\test-api-gateway-get.ps1 -SupabaseToken 'YOUR_TOKEN'" -ForegroundColor Cyan
    Write-Host ""
}

# Summary
Write-Host "=== Test Summary ===" -ForegroundColor Cyan
Write-Host "If all GET requests return 400 (Google HTML error), the optional parameters fix did NOT work." -ForegroundColor Yellow
Write-Host "In that case, implement the workaround from docs/API_GATEWAY_GET_WORKAROUND.md" -ForegroundColor Yellow
Write-Host ""
