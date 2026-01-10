# Script to publish @amanorselliot/shared-types to public npm
# This makes it easier to use in Lovable without registry configuration

param(
    [switch]$DryRun = $false
)

$ErrorActionPreference = "Stop"

Write-Host "=== Publishing to Public npm ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "This will publish @amanorselliot/shared-types to npmjs.com" -ForegroundColor Yellow
Write-Host "This makes it easier to use in Lovable (no registry config needed)" -ForegroundColor Green
Write-Host ""

$packageDir = "shared/types"
if (-not (Test-Path $packageDir)) {
    Write-Host "❌ Error: $packageDir not found" -ForegroundColor Red
    exit 1
}

# Navigate to package directory
Push-Location $packageDir

try {
    # Check if logged in to npm
    $npmWhoami = npm whoami 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "⚠️  Not logged in to npm" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "To publish to npm, you need to:" -ForegroundColor Cyan
        Write-Host "  1. Create account at: https://www.npmjs.com/signup" -ForegroundColor White
        Write-Host "  2. Login: npm login" -ForegroundColor White
        Write-Host "  3. Run this script again" -ForegroundColor White
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

    # Update publishConfig to use npm instead of GitHub Packages
    $packageJson = Get-Content "package.json" | ConvertFrom-Json
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
            Write-Host "  npm install @amanorselliot/shared-types" -ForegroundColor White
            Write-Host ""
            Write-Host "No registry configuration needed!" -ForegroundColor Green
        } else {
            Write-Host "❌ Publish failed" -ForegroundColor Red
            exit 1
        }
    }
} finally {
    Pop-Location
}

Write-Host ""

