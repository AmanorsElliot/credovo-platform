# Script to get a test authentication token
# Supports both Supabase JWT and backend-issued tokens

param(
    [string]$OrchestrationUrl = "https://orchestration-service-saz24fo3sa-ew.a.run.app",
    [string]$UserId = "test-user-$(Get-Date -Format 'yyyyMMddHHmmss')",
    [string]$Email = "test@example.com",
    [string]$Name = "Test User",
    [switch]$UseSupabase = $false,
    [string]$SupabaseToken = ""
)

$ErrorActionPreference = "Stop"

Write-Host "=== Get Test Authentication Token ===" -ForegroundColor Cyan
Write-Host ""

# Option 1: Use provided Supabase token
if ($UseSupabase -and -not [string]::IsNullOrEmpty($SupabaseToken)) {
    Write-Host "Using provided Supabase token" -ForegroundColor Green
    Write-Host ""
    Write-Host "Token: $SupabaseToken" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Use this token in your test script:" -ForegroundColor Cyan
    Write-Host "  .\scripts\test-comprehensive.ps1 -AuthToken `"$SupabaseToken`"" -ForegroundColor White
    exit 0
}

# Option 2: Get backend-issued token (token exchange)
Write-Host "Getting backend-issued token via token exchange..." -ForegroundColor Yellow
Write-Host ""

$tokenRequest = @{
    userId = $UserId
    email = $Email
    name = $Name
}

try {
    $response = Invoke-RestMethod `
        -Uri "$OrchestrationUrl/api/v1/auth/token" `
        -Method Post `
        -Headers @{ "Content-Type" = "application/json" } `
        -Body ($tokenRequest | ConvertTo-Json) `
        -ErrorAction Stop

    Write-Host "✅ Token obtained successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Token Details:" -ForegroundColor Cyan
    Write-Host "  User ID: $($response.user.id)" -ForegroundColor White
    Write-Host "  Email: $($response.user.email)" -ForegroundColor White
    Write-Host "  Expires In: $($response.expiresIn) seconds ($([math]::Round($response.expiresIn / 86400, 1)) days)" -ForegroundColor White
    Write-Host ""
    Write-Host "Token:" -ForegroundColor Yellow
    Write-Host $response.token -ForegroundColor Gray
    Write-Host ""
    Write-Host "Use this token in your test script:" -ForegroundColor Cyan
    Write-Host "  .\scripts\test-comprehensive.ps1 -AuthToken `"$($response.token)`"" -ForegroundColor White
    Write-Host ""
    Write-Host "Or copy to clipboard:" -ForegroundColor Cyan
    $response.token | Set-Clipboard
    Write-Host "  ✅ Token copied to clipboard!" -ForegroundColor Green

} catch {
    Write-Host "❌ Failed to get token" -ForegroundColor Red
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Alternative: Use a Supabase JWT token" -ForegroundColor Yellow
    Write-Host "  1. Log in to your frontend (Lovable)" -ForegroundColor White
    Write-Host "  2. Get the Supabase JWT from browser DevTools" -ForegroundColor White
    Write-Host "  3. Use: .\scripts\get-test-token.ps1 -UseSupabase -SupabaseToken 'your-token'" -ForegroundColor White
    exit 1
}

