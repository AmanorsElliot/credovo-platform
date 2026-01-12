# Deploy Load Balancer for Proxy Service
# This script applies the Terraform configuration to create the Load Balancer

param(
    [string]$ProjectId = "credovo-eu-apps-nonprod"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deploying Load Balancer" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Push-Location infrastructure\terraform

try {
    # Initialize Terraform if needed
    if (-not (Test-Path ".terraform")) {
        Write-Host "Initializing Terraform..." -ForegroundColor Yellow
        terraform init
        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ Terraform init failed" -ForegroundColor Red
            exit 1
        }
    }

    # Plan the changes
    Write-Host "`nPlanning Terraform changes..." -ForegroundColor Yellow
    terraform plan -out=tfplan
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Terraform plan failed" -ForegroundColor Red
        exit 1
    }

    # Apply the changes
    Write-Host "`nApplying Terraform changes..." -ForegroundColor Yellow
    Write-Host "This will create:" -ForegroundColor Gray
    Write-Host "  - Global IP address" -ForegroundColor Gray
    Write-Host "  - Network Endpoint Group (NEG)" -ForegroundColor Gray
    Write-Host "  - Backend Service" -ForegroundColor Gray
    Write-Host "  - URL Map" -ForegroundColor Gray
    Write-Host "  - Target HTTPS/HTTP Proxy" -ForegroundColor Gray
    Write-Host "  - Global Forwarding Rule" -ForegroundColor Gray
    Write-Host "  - Service Account for Load Balancer" -ForegroundColor Gray
    Write-Host ""
    
    terraform apply tfplan
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Terraform apply failed" -ForegroundColor Red
        exit 1
    }

    # Get the outputs
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Load Balancer Deployment Complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    $lbIp = terraform output -raw load_balancer_ip
    $lbUrl = terraform output -raw load_balancer_url
    
    Write-Host "Load Balancer IP: $lbIp" -ForegroundColor Cyan
    Write-Host "Load Balancer URL: $lbUrl" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "1. Test the Load Balancer:" -ForegroundColor White
    Write-Host "   .\scripts\test-load-balancer.ps1 -LoadBalancerUrl `"$lbUrl`"" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Update Edge Function environment variable:" -ForegroundColor White
    Write-Host "   PROXY_SERVICE_URL=$lbUrl" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. Verify IAM binding:" -ForegroundColor White
    Write-Host "   gcloud run services get-iam-policy proxy-service `" -ForegroundColor Gray
    Write-Host "       --region=europe-west1 `" -ForegroundColor Gray
    Write-Host "       --project=$ProjectId" -ForegroundColor Gray
    
} catch {
    Write-Host "❌ Error: $_" -ForegroundColor Red
    exit 1
} finally {
    Pop-Location
}
