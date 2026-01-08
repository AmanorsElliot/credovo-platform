# Test script to verify frontend-backend communication
# Tests all endpoints to ensure backend is accessible and working

param(
    [string]$BackendUrl = "https://orchestration-service-saz24fo3sa-ew.a.run.app"
)

$ErrorActionPreference = "Continue"

Write-Host "=== Testing Backend Connection ===" -ForegroundColor Cyan
Write-Host "Backend URL: $BackendUrl" -ForegroundColor Gray
Write-Host ""

# Test 1: Health Check (No auth required)
Write-Host "Test 1: Health Check Endpoint" -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "$BackendUrl/health" -Method GET -UseBasicParsing
    Write-Host "Status: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "Response: $($response.Content)" -ForegroundColor Green
    Write-Host "✅ Health check passed!" -ForegroundColor Green
} catch {
    Write-Host "❌ Health check failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        Write-Host "Status Code: $($_.Exception.Response.StatusCode)" -ForegroundColor Red
    }
}
Write-Host ""

# Test 2: CORS Preflight (OPTIONS request)
Write-Host "Test 2: CORS Preflight Check" -ForegroundColor Yellow
try {
    $headers = @{
        "Origin" = "https://app.lovable.dev"
        "Access-Control-Request-Method" = "POST"
        "Access-Control-Request-Headers" = "Content-Type,Authorization"
    }
    $response = Invoke-WebRequest -Uri "$BackendUrl/api/v1/auth/verify" -Method OPTIONS -Headers $headers -UseBasicParsing
    Write-Host "Status: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "CORS Headers:" -ForegroundColor Cyan
    $response.Headers | Where-Object { $_.Key -like "*Access-Control*" } | ForEach-Object {
        Write-Host "  $($_.Key): $($_.Value)" -ForegroundColor Gray
    }
    Write-Host "✅ CORS preflight passed!" -ForegroundColor Green
} catch {
    Write-Host "❌ CORS preflight failed: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 3: Auth Verify Endpoint (No token - should fail gracefully)
Write-Host "Test 3: Auth Verify (No Token - Expected to Fail)" -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "$BackendUrl/api/v1/auth/verify" -Method GET -UseBasicParsing
    Write-Host "Status: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "Response: $($response.Content)" -ForegroundColor Green
} catch {
    if ($_.Exception.Response.StatusCode -eq 401) {
        Write-Host "✅ Correctly returned 401 (Unauthorized) - Expected behavior" -ForegroundColor Green
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $responseBody = $reader.ReadToEnd()
        Write-Host "Response: $responseBody" -ForegroundColor Gray
    } else {
        Write-Host "❌ Unexpected error: $($_.Exception.Message)" -ForegroundColor Red
    }
}
Write-Host ""

# Test 4: Auth Verify with Invalid Token
Write-Host "Test 4: Auth Verify (Invalid Token)" -ForegroundColor Yellow
try {
    $headers = @{
        "Authorization" = "Bearer invalid-token-12345"
    }
    $response = Invoke-WebRequest -Uri "$BackendUrl/api/v1/auth/verify" -Method GET -Headers $headers -UseBasicParsing
    Write-Host "Status: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "Response: $($response.Content)" -ForegroundColor Green
} catch {
    if ($_.Exception.Response.StatusCode -eq 401) {
        Write-Host "✅ Correctly rejected invalid token (401)" -ForegroundColor Green
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $responseBody = $reader.ReadToEnd()
        Write-Host "Response: $responseBody" -ForegroundColor Gray
    } else {
        Write-Host "❌ Unexpected error: $($_.Exception.Message)" -ForegroundColor Red
    }
}
Write-Host ""

# Test 5: Token Exchange Endpoint (if using backend JWT)
Write-Host "Test 5: Token Exchange Endpoint" -ForegroundColor Yellow
try {
    $body = @{
        userId = "test-user-123"
        email = "test@example.com"
        name = "Test User"
    } | ConvertTo-Json

    $headers = @{
        "Content-Type" = "application/json"
    }

    $response = Invoke-WebRequest -Uri "$BackendUrl/api/v1/auth/token" -Method POST -Body $body -Headers $headers -UseBasicParsing
    Write-Host "Status: $($response.StatusCode)" -ForegroundColor Green
    $responseData = $response.Content | ConvertFrom-Json
    Write-Host "✅ Token exchange successful!" -ForegroundColor Green
    Write-Host "Token received: $($responseData.token.Substring(0, 20))..." -ForegroundColor Gray
    Write-Host "User ID: $($responseData.user.id)" -ForegroundColor Gray
    
    # Store token for next test
    $script:testToken = $responseData.token
} catch {
    Write-Host "❌ Token exchange failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $responseBody = $reader.ReadToEnd()
        Write-Host "Response: $responseBody" -ForegroundColor Red
    }
}
Write-Host ""

# Test 6: Verify Token with Valid Token (if we got one)
if ($script:testToken) {
    Write-Host "Test 6: Auth Verify (Valid Token)" -ForegroundColor Yellow
    try {
        $headers = @{
            "Authorization" = "Bearer $($script:testToken)"
        }
        $response = Invoke-WebRequest -Uri "$BackendUrl/api/v1/auth/verify" -Method GET -Headers $headers -UseBasicParsing
        Write-Host "Status: $($response.StatusCode)" -ForegroundColor Green
        $responseData = $response.Content | ConvertFrom-Json
        Write-Host "✅ Token verification successful!" -ForegroundColor Green
        Write-Host "User: $($responseData.user | ConvertTo-Json)" -ForegroundColor Gray
    } catch {
        Write-Host "❌ Token verification failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ""
}

# Test 7: Protected Endpoint (should require auth)
Write-Host "Test 7: Protected Endpoint (No Auth - Should Fail)" -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "$BackendUrl/api/v1/applications" -Method GET -UseBasicParsing
    Write-Host "Status: $($response.StatusCode)" -ForegroundColor Green
} catch {
    if ($_.Exception.Response.StatusCode -eq 401) {
        Write-Host "✅ Correctly protected endpoint (401 Unauthorized)" -ForegroundColor Green
    } else {
        Write-Host "❌ Unexpected error: $($_.Exception.Message)" -ForegroundColor Red
    }
}
Write-Host ""

# Summary
Write-Host "=== Test Summary ===" -ForegroundColor Cyan
Write-Host "Backend URL: $BackendUrl" -ForegroundColor Gray
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. If health check passed, backend is accessible" -ForegroundColor Gray
Write-Host "2. If CORS passed, frontend can make requests" -ForegroundColor Gray
Write-Host "3. Test from Lovable frontend with Supabase JWT token" -ForegroundColor Gray
Write-Host ""
Write-Host "To test from frontend:" -ForegroundColor Yellow
Write-Host "  const response = await fetch('$BackendUrl/health');" -ForegroundColor Cyan
Write-Host "  const data = await response.json();" -ForegroundColor Cyan
Write-Host "  console.log(data);" -ForegroundColor Cyan

