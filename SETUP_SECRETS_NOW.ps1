# Quick setup script for GCP secrets
# Run this after Terraform has created the secret placeholders

Write-Host "=== Setting up GCP Secrets ===" -ForegroundColor Cyan
Write-Host ""

# Set project
gcloud config set project credovo-eu-apps-nonprod

# 1. Supabase URL (REQUIRED)
Write-Host "1. Adding Supabase URL..." -ForegroundColor Yellow
$supabaseUrl = "https://jywjbinndnanxscxqdes.supabase.co"
echo -n $supabaseUrl | gcloud secrets versions add supabase-url --data-file=-
Write-Host "   [OK] Supabase URL configured" -ForegroundColor Green
Write-Host "   JWKS endpoint: $supabaseUrl/auth/v1/.well-known/jwks.json" -ForegroundColor Gray

# 2. Service JWT Secret (REQUIRED - Auto-generated)
Write-Host ""
Write-Host "2. Generating Service JWT Secret..." -ForegroundColor Yellow
$jwtSecret = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 64 | ForEach-Object {[char]$_})
$jwtSecretBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($jwtSecret))
$jwtSecretBase64 | gcloud secrets versions add service-jwt-secret --data-file=-
Write-Host "   [OK] Service JWT Secret generated and configured" -ForegroundColor Green

# 3. Optional: Lovable JWKS URI (for fallback)
Write-Host ""
Write-Host "3. Adding Lovable JWKS URI (optional)..." -ForegroundColor Yellow
$jwksUri = "https://auth.lovable.dev/.well-known/jwks.json"
echo -n $jwksUri | gcloud secrets versions add lovable-jwks-uri --data-file=-
Write-Host "   [OK] Lovable JWKS URI configured" -ForegroundColor Green

# 4. Optional: Lovable Audience
Write-Host ""
Write-Host "4. Adding Lovable Audience (optional)..." -ForegroundColor Yellow
$audience = "credovo-api"
echo -n $audience | gcloud secrets versions add lovable-audience --data-file=-
Write-Host "   [OK] Lovable Audience configured" -ForegroundColor Green

Write-Host ""
Write-Host "=== Secrets Setup Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Get orchestration service URL:" -ForegroundColor White
Write-Host "   cd infrastructure/terraform" -ForegroundColor Gray
Write-Host "   terraform output orchestration_service_url" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Add to Lovable environment variables:" -ForegroundColor White
Write-Host "   REACT_APP_API_URL = <orchestration-service-url>" -ForegroundColor Gray
Write-Host ""

