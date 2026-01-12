# Deploy Load Balancer using targeted Terraform apply
# This targets only Load Balancer resources to avoid other Terraform errors

param(
    [string]$ProjectId = "credovo-eu-apps-nonprod"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deploying Load Balancer (Targeted)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Push-Location infrastructure\terraform

try {
    # Initialize if needed
    if (-not (Test-Path ".terraform")) {
        Write-Host "Initializing Terraform..." -ForegroundColor Yellow
        terraform init
        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ Terraform init failed" -ForegroundColor Red
            exit 1
        }
    }

    # Plan with targets
    Write-Host "`nPlanning Load Balancer resources..." -ForegroundColor Yellow
    
    $targets = @(
        "google_service_account.load_balancer",
        "google_cloud_run_service_iam_member.load_balancer_invoke_proxy",
        "google_compute_global_address.proxy_ip",
        "google_compute_region_network_endpoint_group.proxy_neg",
        "google_compute_backend_service.proxy_backend",
        "google_compute_url_map.proxy_url_map",
        "google_compute_target_http_proxy.proxy_http",
        "google_compute_global_forwarding_rule.proxy_http_forwarding"
    )
    
    $targetArgs = $targets | ForEach-Object { "-target=$_" }
    
    terraform plan $targetArgs -out=tfplan-lb
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Terraform plan failed" -ForegroundColor Red
        exit 1
    }

    # Apply
    Write-Host "`nApplying Load Balancer configuration..." -ForegroundColor Yellow
    terraform apply tfplan-lb
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Terraform apply failed" -ForegroundColor Red
        exit 1
    }

    # Get outputs
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Load Balancer Deployed!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    $lbIp = terraform output -raw load_balancer_ip
    $lbUrl = terraform output -raw load_balancer_url
    
    if ($lbIp) {
        Write-Host "✅ Load Balancer IP: $lbIp" -ForegroundColor Green
        Write-Host "✅ Load Balancer URL: $lbUrl" -ForegroundColor Green
        Write-Host ""
        Write-Host "Next Steps:" -ForegroundColor Yellow
        Write-Host "1. Test: .\scripts\test-load-balancer.ps1 -LoadBalancerUrl `"$lbUrl`"" -ForegroundColor White
        Write-Host "2. Update Edge Function: PROXY_SERVICE_URL=$lbUrl" -ForegroundColor White
    } else {
        Write-Host "⚠️  Could not get Load Balancer IP from outputs" -ForegroundColor Yellow
        Write-Host "Check Terraform state manually" -ForegroundColor Gray
    }
    
} catch {
    Write-Host "❌ Error: $_" -ForegroundColor Red
    exit 1
} finally {
    Pop-Location
}
