# Script to build and publish @amanorselliot/shared-types npm package
# This package is used by the credovo-webapp frontend repository

param(
    [switch]$DryRun = $false,
    [string]$Registry = "github"  # "github" or "npm"
)

$ErrorActionPreference = "Stop"

Write-Host "=== Publishing @amanorselliot/shared-types ===" -ForegroundColor Cyan
Write-Host ""

$packageDir = "shared/types"
if (-not (Test-Path $packageDir)) {
    Write-Host "❌ Error: $packageDir not found" -ForegroundColor Red
    exit 1
}

# Check if tsconfig.json exists
$tsconfigPath = Join-Path $packageDir "tsconfig.json"
if (-not (Test-Path $tsconfigPath)) {
    Write-Host "Creating tsconfig.json..." -ForegroundColor Yellow
    $tsconfig = @{
        compilerOptions = @{
            target = "ES2020"
            module = "commonjs"
            declaration = $true
            outDir = "./dist"
            rootDir = "./"
            strict = $true
            esModuleInterop = $true
            skipLibCheck = $true
            forceConsistentCasingInFileNames = $true
        }
        include = @("index.ts")
        exclude = @("node_modules", "dist")
    } | ConvertTo-Json -Depth 10
    
    Set-Content -Path $tsconfigPath -Value $tsconfig
    Write-Host "✅ Created tsconfig.json" -ForegroundColor Green
}

# Navigate to package directory
Push-Location $packageDir

try {
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

    # Check if dist directory was created
    if (-not (Test-Path "dist")) {
        Write-Host "❌ Error: dist directory not created" -ForegroundColor Red
        exit 1
    }

    Write-Host "✅ Build successful" -ForegroundColor Green
    Write-Host ""

    # Determine registry
    $publishCommand = "npm publish"
    if ($Registry -eq "github") {
        $publishCommand = "npm publish --registry=https://npm.pkg.github.com"
        Write-Host "Publishing to GitHub Packages..." -ForegroundColor Yellow
    } else {
        Write-Host "Publishing to npm..." -ForegroundColor Yellow
        if (-not $DryRun) {
            $publishCommand = "$publishCommand --access public"
        }
    }

    if ($DryRun) {
        Write-Host ""
        Write-Host "=== DRY RUN - Would execute ===" -ForegroundColor Yellow
        Write-Host "  $publishCommand" -ForegroundColor Gray
        Write-Host ""
        Write-Host "To actually publish, run without -DryRun flag:" -ForegroundColor Cyan
        Write-Host "  .\scripts\publish-shared-types.ps1" -ForegroundColor White
    } else {
        Write-Host "Publishing package..." -ForegroundColor Yellow
        Invoke-Expression $publishCommand
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "✅ Package published successfully!" -ForegroundColor Green
            Write-Host ""
            Write-Host "To install in credovo-webapp:" -ForegroundColor Cyan
            if ($Registry -eq "github") {
                Write-Host "  npm install @amanorselliot/shared-types --registry=https://npm.pkg.github.com" -ForegroundColor White
            } else {
                Write-Host "  npm install @amanorselliot/shared-types" -ForegroundColor White
            }
        } else {
            Write-Host "❌ Publish failed" -ForegroundColor Red
            exit 1
        }
    }
} finally {
    Pop-Location
}

Write-Host ""

