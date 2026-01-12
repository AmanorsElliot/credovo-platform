# Test Load Balancer Connection
# This script tests the Load Balancer to ensure it's properly routing to the proxy service

param(
    [string]$LoadBalancerUrl = "",
    [string]$ProjectId = "credovo-eu-apps-nonprod"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Testing Load Balancer" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# If URL not provided, try to get it from Terraform
if (-not $LoadBalancerUrl) {
    Write-Host "Getting Load Balancer URL from Terraform..." -ForegroundColor Yellow
    
    Push-Location infrastructure/terraform
    try {
        $LoadBalancerUrl = terraform output -raw load_balancer_url
        if (-not $LoadBalancerUrl) {
            Write-Host "❌ Could not get Load Balancer URL from Terraform" -ForegroundColor Red
            Write-Host "Please provide the URL manually: -LoadBalancerUrl 'http://<IP>'" -ForegroundColor Yellow
            exit 1
        }
        Write-Host "✅ Found Load Balancer URL: $LoadBalancerUrl" -ForegroundColor Green
    } catch {
        Write-Host "❌ Error getting URL from Terraform: $_" -ForegroundColor Red
        exit 1
    } finally {
        Pop-Location
    }
}

Write-Host ""
Write-Host "Load Balancer URL: $LoadBalancerUrl" -ForegroundColor Cyan
Write-Host ""

# Test 1: Health endpoint
Write-Host "Test 1: Health Endpoint" -ForegroundColor Yellow
try {
    $healthResponse = Invoke-RestMethod -Uri "$LoadBalancerUrl/health" -Method GET -ErrorAction Stop
    Write-Host "✅ Health check passed" -ForegroundColor Green
    Write-Host "Response: $($healthResponse | ConvertTo-Json)" -ForegroundColor Gray
} catch {
    Write-Host "❌ Health check failed: $_" -ForegroundColor Red
    Write-Host "This might be normal if the proxy service doesn't have a /health endpoint" -ForegroundColor Yellow
}

Write-Host ""

# Test 2: Check if Load Balancer is accessible
Write-Host "Test 2: Load Balancer Accessibility" -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri $LoadBalancerUrl -Method GET -ErrorAction Stop -TimeoutSec 10
    Write-Host "✅ Load Balancer is accessible" -ForegroundColor Green
    Write-Host "Status Code: $($response.StatusCode)" -ForegroundColor Gray
    Write-Host "Content Length: $($response.Content.Length) bytes" -ForegroundColor Gray
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 404) {
        Write-Host "⚠️  Load Balancer accessible but returned 404 (expected if no default route)" -ForegroundColor Yellow
    } elseif ($statusCode -eq 502) {
        Write-Host "❌ Load Balancer returned 502 Bad Gateway" -ForegroundColor Red
        Write-Host "This usually means:" -ForegroundColor Yellow
        Write-Host "  1. Proxy service is not running" -ForegroundColor White
        Write-Host "  2. IAM binding is missing (Load Balancer can't invoke proxy service)" -ForegroundColor White
        Write-Host "  3. Network Endpoint Group (NEG) is not configured correctly" -ForegroundColor White
        Write-Host ""
        Write-Host "Checking IAM binding..." -ForegroundColor Yellow
        gcloud run services get-iam-policy proxy-service `
            --region=europe-west1 `
            --project=$ProjectId `
            --format="table(bindings.role,bindings.members)"
    } else {
        Write-Host "❌ Error accessing Load Balancer: $_" -ForegroundColor Red
        Write-Host "Status Code: $statusCode" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. If health check passed, update Edge Function with: $LoadBalancerUrl" -ForegroundColor White
Write-Host "2. Test the full flow from Supabase Edge Function" -ForegroundColor White
Write-Host "3. Monitor Cloud Run logs for proxy service" -ForegroundColor White
