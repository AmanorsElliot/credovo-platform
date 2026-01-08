# PowerShell script to configure GCP Secret Manager secrets
# Run this after Terraform has created the secret placeholders

param(
    [string]$ProjectId = "credovo-eu-apps-nonprod"
)

Write-Host "=== GCP Secret Manager Configuration ===" -ForegroundColor Cyan
Write-Host ""

# Set project
gcloud config set project $ProjectId

Write-Host "This script will help you configure secrets in GCP Secret Manager." -ForegroundColor Yellow
Write-Host "Some secrets will be generated automatically, others require your input." -ForegroundColor Yellow
Write-Host ""

# 1. Supabase URL (REQUIRED for Supabase auth)
Write-Host "1. Configuring Supabase URL..." -ForegroundColor Yellow
$supabaseUrl = Read-Host "Enter your Supabase Project URL (e.g., https://xxx.supabase.co)"
if ($supabaseUrl) {
    $supabaseUrl | gcloud secrets versions add supabase-url --data-file=-
    Write-Host "   [OK] Supabase URL configured" -ForegroundColor Green
} else {
    Write-Host "   [ERROR] Supabase URL is required!" -ForegroundColor Red
    Write-Host "   Configure later with:" -ForegroundColor Yellow
    Write-Host "     echo -n 'https://your-project.supabase.co' | gcloud secrets versions add supabase-url --data-file=-" -ForegroundColor Gray
}

# 2. Service JWT Secret (generate random - for fallback token exchange)
Write-Host ""
Write-Host "2. Generating Service JWT Secret..." -ForegroundColor Yellow
$jwtSecret = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 64 | ForEach-Object {[char]$_})
$jwtSecretBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($jwtSecret))
$jwtSecretBase64 | gcloud secrets versions add service-jwt-secret --data-file=-
Write-Host "   [OK] Service JWT Secret generated and configured" -ForegroundColor Green

# 3. Lovable JWKS URI (optional - only if not using Supabase)
Write-Host ""
Write-Host "3. Configuring Lovable JWKS URI (optional)..." -ForegroundColor Yellow
$jwksUri = "https://auth.lovable.dev/.well-known/jwks.json"
$jwksUri | gcloud secrets versions add lovable-jwks-uri --data-file=-
Write-Host "   [OK] Lovable JWKS URI configured" -ForegroundColor Green

# 4. Lovable Audience (optional - only if not using Supabase)
Write-Host ""
Write-Host "4. Configuring Lovable Audience (optional)..." -ForegroundColor Yellow
$audience = "credovo-api"
$audience | gcloud secrets versions add lovable-audience --data-file=-
Write-Host "   [OK] Lovable Audience configured" -ForegroundColor Green

# 5. SumSub API Key (optional)
Write-Host ""
Write-Host "5. Configuring SumSub API Key (optional)..." -ForegroundColor Yellow
$sumsubKey = Read-Host "Enter your SumSub API Key (or press Enter to skip)"
if ($sumsubKey) {
    $sumsubKey | gcloud secrets versions add sumsub-api-key --data-file=-
    Write-Host "   [OK] SumSub API Key configured" -ForegroundColor Green
} else {
    Write-Host "   [SKIP] SumSub API Key skipped. Configure later with:" -ForegroundColor Yellow
    Write-Host "     echo -n 'your-key' | gcloud secrets versions add sumsub-api-key --data-file=-" -ForegroundColor Gray
}

# 6. Companies House API Key (optional)
Write-Host ""
Write-Host "6. Configuring Companies House API Key (optional)..." -ForegroundColor Yellow
$companiesHouseKey = Read-Host "Enter your Companies House API Key (or press Enter to skip)"
if ($companiesHouseKey) {
    $companiesHouseKey | gcloud secrets versions add companies-house-api-key --data-file=-
    Write-Host "   [OK] Companies House API Key configured" -ForegroundColor Green
} else {
    Write-Host "   [SKIP] Companies House API Key skipped. Configure later with:" -ForegroundColor Yellow
    Write-Host "     echo -n 'your-key' | gcloud secrets versions add companies-house-api-key --data-file=-" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=== Secret Configuration Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "To verify secrets:" -ForegroundColor Cyan
Write-Host "  gcloud secrets list" -ForegroundColor White
Write-Host ""
Write-Host "To view a secret value:" -ForegroundColor Cyan
Write-Host "  gcloud secrets versions access latest --secret=SECRET_NAME" -ForegroundColor White
