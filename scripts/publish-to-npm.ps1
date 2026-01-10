# Script to publish @credovo/shared-types to public npm
# This makes it easier to use in Lovable without registry configuration

param(
    [switch]$DryRun = $false
)

$ErrorActionPreference = "Stop"

Write-Host "=== Publishing to Public npm ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "This will publish @credovo/shared-types to npmjs.com" -ForegroundColor Yellow
Write-Host "This makes it easier to use in Lovable (no registry config needed)" -ForegroundColor Green
Write-Host ""
Write-Host "Note: Granular tokens require 2FA bypass enabled" -ForegroundColor Gray
Write-Host "      Use 'npm login' and paste token as password (not --auth-type=legacy)" -ForegroundColor Gray
Write-Host ""

# Get the script's directory and find repository root
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir
$packageDir = Join-Path $repoRoot "shared/types"

# Change to repository root
Push-Location $repoRoot

if (-not (Test-Path $packageDir)) {
    Write-Host "❌ Error: $packageDir not found" -ForegroundColor Red
    Write-Host "Expected path: $packageDir" -ForegroundColor Yellow
    Pop-Location
    exit 1
}

# Navigate to package directory (from repo root)
Push-Location $packageDir

try {
    # Check if logged in to npm
    $npmWhoami = npm whoami 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "⚠️  Not logged in to npm" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "To publish to npm, you need to:" -ForegroundColor Cyan
        Write-Host "  1. Create account at: https://www.npmjs.com/signup" -ForegroundColor White
        Write-Host "  2. Enable 2FA: https://www.npmjs.com/settings/$npmWhoami/two-factor/auth" -ForegroundColor White
        Write-Host "     (npm requires 2FA to publish packages)" -ForegroundColor Yellow
        Write-Host "  3. Login: npm login (will prompt for 2FA code)" -ForegroundColor White
        Write-Host "  4. Run this script again" -ForegroundColor White
        Write-Host ""
        exit 1
    }

    Write-Host "Logged in as: $npmWhoami" -ForegroundColor Green
    Write-Host ""

    # Install dependencies if needed
    if (-not (Test-Path "node_modules")) {
        Write-Host "Installing dependencies..." -ForegroundColor Yellow
        npm install
    }

    # Build the package
    Write-Host "Building package..." -ForegroundColor Yellow
    npm run build
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Build failed" -ForegroundColor Red
        exit 1
    }

    Write-Host "✅ Build successful" -ForegroundColor Green
    Write-Host ""

    # Temporarily update publishConfig to use npm (will revert after publish)
    $originalPackageJson = Get-Content "package.json" -Raw
    $packageJson = $originalPackageJson | ConvertFrom-Json
    $packageJson.publishConfig = @{
        registry = "https://registry.npmjs.org"
    }
    $packageJson | ConvertTo-Json -Depth 10 | Set-Content "package.json"

    if ($DryRun) {
        Write-Host "=== DRY RUN - Would execute ===" -ForegroundColor Yellow
        Write-Host "  npm publish --access public" -ForegroundColor Gray
        Write-Host ""
        Write-Host "To actually publish, run without -DryRun flag:" -ForegroundColor Cyan
        Write-Host "  .\scripts\publish-to-npm.ps1" -ForegroundColor White
    } else {
        Write-Host "Publishing to npm..." -ForegroundColor Yellow
        npm publish --access public
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "✅ Package published to npm successfully!" -ForegroundColor Green
            Write-Host ""
            Write-Host "To install in credovo-webapp:" -ForegroundColor Cyan
            Write-Host "  npm install @credovo/shared-types" -ForegroundColor White
            Write-Host ""
            Write-Host "No registry configuration needed!" -ForegroundColor Green
            Write-Host ""
            Write-Host "Package URL: https://www.npmjs.com/package/@credovo/shared-types" -ForegroundColor Cyan
        } else {
            Write-Host "❌ Publish failed" -ForegroundColor Red
            # Restore original package.json
            Set-Content -Path "package.json" -Value $originalPackageJson
            exit 1
        }
    }
} finally {
    # Restore original package.json if we modified it
    if ($originalPackageJson) {
        Set-Content -Path "package.json" -Value $originalPackageJson
        Write-Host "Restored package.json to original config" -ForegroundColor Gray
    }
    Pop-Location  # Exit package directory
    Pop-Location  # Exit repo root (return to original directory)
}

Write-Host ""

