# PowerShell script to configure GCP Secret Manager secrets
# Run this after Terraform deployment

param(
    [string]$ProjectId = "credovo-eu-apps-nonprod",
    [string]$SupabaseUrl = "",
    [string]$SumsubApiKey = "",
    [string]$CompaniesHouseApiKey = ""
)

Write-Host "=== Configuring GCP Secret Manager Secrets ===" -ForegroundColor Cyan
Write-Host ""

# Set project
gcloud config set project $ProjectId

# 1. Supabase URL (REQUIRED)
if ($SupabaseUrl) {
    Write-Host "Adding Supabase URL..." -ForegroundColor Yellow
    $SupabaseUrl | gcloud secrets versions add supabase-url --data-file=-
    Write-Host "✓ Supabase URL configured" -ForegroundColor Green
} else {
    Write-Host "⚠ Supabase URL not provided. Please add it manually:" -ForegroundColor Yellow
    Write-Host "  echo -n 'https://your-project.supabase.co' | gcloud secrets versions add supabase-url --data-file=-" -ForegroundColor Gray
}

# 2. Service JWT Secret (REQUIRED - Auto-generated)
Write-Host ""
Write-Host "Generating Service JWT Secret..." -ForegroundColor Yellow
$jwtSecret = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 64 | ForEach-Object {[char]$_})
$jwtSecretBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($jwtSecret))
$jwtSecretBase64 | gcloud secrets versions add service-jwt-secret --data-file=-
Write-Host "✓ Service JWT Secret generated and configured" -ForegroundColor Green

# 3. Optional: Lovable JWKS URI (if not using Supabase)
Write-Host ""
Write-Host "Adding Lovable JWKS URI (optional)..." -ForegroundColor Yellow
$jwksUri = "https://auth.lovable.dev/.well-known/jwks.json"
$jwksUri | gcloud secrets versions add lovable-jwks-uri --data-file=-
Write-Host "✓ Lovable JWKS URI configured" -ForegroundColor Green

# 4. Optional: Lovable Audience
Write-Host ""
Write-Host "Adding Lovable Audience (optional)..." -ForegroundColor Yellow
$audience = "credovo-api"
$audience | gcloud secrets versions add lovable-audience --data-file=-
Write-Host "✓ Lovable Audience configured" -ForegroundColor Green

# 5. Optional: SumSub API Key
if ($SumsubApiKey) {
    Write-Host ""
    Write-Host "Adding SumSub API Key..." -ForegroundColor Yellow
    $SumsubApiKey | gcloud secrets versions add sumsub-api-key --data-file=-
    Write-Host "✓ SumSub API Key configured" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "⚠ SumSub API Key not provided (optional)" -ForegroundColor Yellow
}

# 6. Optional: Companies House API Key
if ($CompaniesHouseApiKey) {
    Write-Host ""
    Write-Host "Adding Companies House API Key..." -ForegroundColor Yellow
    $CompaniesHouseApiKey | gcloud secrets versions add companies-house-api-key --data-file=-
    Write-Host "✓ Companies House API Key configured" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "⚠ Companies House API Key not provided (optional)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Secret Configuration Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "To verify secrets:" -ForegroundColor Cyan
Write-Host "  gcloud secrets list" -ForegroundColor Gray
Write-Host "  gcloud secrets versions access latest --secret=supabase-url" -ForegroundColor Gray

