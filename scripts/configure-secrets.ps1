# PowerShell script to configure GCP Secret Manager secrets
# Run this after Terraform has created the secret placeholders

param(
    [string]$ProjectId = "credovo-platform-dev"
)

Write-Host "=== GCP Secret Manager Configuration ===" -ForegroundColor Cyan
Write-Host ""

# Set project
gcloud config set project $ProjectId

Write-Host "This script will help you configure secrets in GCP Secret Manager." -ForegroundColor Yellow
Write-Host "Some secrets will be generated automatically, others require your input." -ForegroundColor Yellow
Write-Host ""

# 1. Lovable JWKS URI
Write-Host "1. Configuring Lovable JWKS URI..." -ForegroundColor Yellow
$jwksUri = "https://auth.lovable.dev/.well-known/jwks.json"
$jwksUri | gcloud secrets versions add lovable-jwks-uri --data-file=-
Write-Host "   ✓ Lovable JWKS URI configured" -ForegroundColor Green

# 2. Lovable Audience
Write-Host ""
Write-Host "2. Configuring Lovable Audience..." -ForegroundColor Yellow
$audience = "credovo-api"
$audience | gcloud secrets versions add lovable-audience --data-file=-
Write-Host "   ✓ Lovable Audience configured" -ForegroundColor Green

# 3. Service JWT Secret (generate random)
Write-Host ""
Write-Host "3. Generating Service JWT Secret..." -ForegroundColor Yellow
$jwtSecret = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | ForEach-Object {[char]$_})
$jwtSecretBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($jwtSecret))
$jwtSecretBase64 | gcloud secrets versions add service-jwt-secret --data-file=-
Write-Host "   ✓ Service JWT Secret generated and configured" -ForegroundColor Green

# 4. SumSub API Key
Write-Host ""
Write-Host "4. Configuring SumSub API Key..." -ForegroundColor Yellow
$sumsubKey = Read-Host "Enter your SumSub API Key (or press Enter to skip)"
if ($sumsubKey) {
    $sumsubKey | gcloud secrets versions add sumsub-api-key --data-file=-
    Write-Host "   ✓ SumSub API Key configured" -ForegroundColor Green
} else {
    Write-Host "   ⚠ SumSub API Key skipped. Configure later with:" -ForegroundColor Yellow
    Write-Host "     echo -n 'your-key' | gcloud secrets versions add sumsub-api-key --data-file=-" -ForegroundColor Gray
}

# 5. Companies House API Key
Write-Host ""
Write-Host "5. Configuring Companies House API Key..." -ForegroundColor Yellow
$companiesHouseKey = Read-Host "Enter your Companies House API Key (or press Enter to skip)"
if ($companiesHouseKey) {
    $companiesHouseKey | gcloud secrets versions add companies-house-api-key --data-file=-
    Write-Host "   ✓ Companies House API Key configured" -ForegroundColor Green
} else {
    Write-Host "   ⚠ Companies House API Key skipped. Configure later with:" -ForegroundColor Yellow
    Write-Host "     echo -n 'your-key' | gcloud secrets versions add companies-house-api-key --data-file=-" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=== Secret Configuration Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "To verify secrets:" -ForegroundColor Cyan
Write-Host "  gcloud secrets list" -ForegroundColor White
Write-Host ""
Write-Host "To view a secret value:" -ForegroundColor Cyan
$secretCmd = "gcloud secrets versions access latest --secret=SECRET_NAME"
Write-Host "  $secretCmd" -ForegroundColor White

