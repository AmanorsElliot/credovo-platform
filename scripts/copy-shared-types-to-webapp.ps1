# Script to copy shared types to credovo-webapp
# Useful when you can't install the npm package in Lovable

param(
    [string]$WebappPath = "C:\Users\ellio\Documents\credovo-webapp",
    [string]$TypesPath = "shared/types/index.ts"
)

$ErrorActionPreference = "Stop"

Write-Host "=== Copying Shared Types to credovo-webapp ===" -ForegroundColor Cyan
Write-Host ""

# Check if types file exists
$sourceFile = Join-Path $PSScriptRoot "..\$TypesPath"
if (-not (Test-Path $sourceFile)) {
    Write-Host "❌ Error: Types file not found at $sourceFile" -ForegroundColor Red
    exit 1
}

# Check if webapp directory exists
if (-not (Test-Path $WebappPath)) {
    Write-Host "⚠️  Webapp directory not found: $WebappPath" -ForegroundColor Yellow
    $create = Read-Host "Create directory? (y/n)"
    if ($create -eq "y") {
        New-Item -ItemType Directory -Path $WebappPath -Force | Out-Null
        Write-Host "✅ Created directory" -ForegroundColor Green
    } else {
        exit
    }
}

# Create types directory in webapp
$targetDir = Join-Path $WebappPath "src\types"
if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    Write-Host "✅ Created src/types directory" -ForegroundColor Green
}

# Copy types file
$targetFile = Join-Path $targetDir "shared-types.ts"
Copy-Item -Path $sourceFile -Destination $targetFile -Force

Write-Host "✅ Copied types to: $targetFile" -ForegroundColor Green
Write-Host ""

# Show usage example
Write-Host "=== Usage ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "In your code, import from:" -ForegroundColor Yellow
Write-Host "  import { KYCRequest, KYCResponse } from './types/shared-types';" -ForegroundColor White
Write-Host ""
Write-Host "Or if using absolute imports:" -ForegroundColor Yellow
Write-Host "  import { KYCRequest, KYCResponse } from '@/types/shared-types';" -ForegroundColor White
Write-Host ""
Write-Host "Note: Update imports when types change in credovo-platform" -ForegroundColor Gray
Write-Host ""

