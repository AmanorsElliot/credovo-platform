# Script to help set up a separate frontend repository
# This is the SAFEST approach for Lovable integration

param(
    [string]$FrontendRepoName = "credovo-frontend",
    [string]$BackendRepoPath = "."
)

$ErrorActionPreference = "Stop"

Write-Host "=== Separate Frontend Repository Setup ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "This script helps you set up a separate repository for the frontend." -ForegroundColor Yellow
Write-Host "This is the SAFEST approach - Lovable can't overwrite backend files!" -ForegroundColor Green
Write-Host ""

# Step 1: Check if shared/types is ready to publish
Write-Host "Step 1: Checking shared/types package..." -ForegroundColor Yellow
$typesPath = Join-Path $BackendRepoPath "shared\types\package.json"

if (-not (Test-Path $typesPath)) {
    Write-Host "⚠️  shared/types/package.json not found" -ForegroundColor Yellow
    Write-Host "Creating package.json for shared types..." -ForegroundColor Gray
    
    $packageJson = @{
        name = "@credovo/shared-types"
        version = "1.0.0"
        description = "Shared TypeScript types for Credovo platform"
        main = "dist/index.js"
        types = "dist/index.d.ts"
        scripts = @{
            build = "tsc"
        }
        publishConfig = @{
            registry = "https://npm.pkg.github.com"
        }
        repository = @{
            type = "git"
            url = "https://github.com/AmanorsElliot/credovo-platform.git"
        }
    } | ConvertTo-Json -Depth 10
    
    Set-Content -Path $typesPath -Value $packageJson
    Write-Host "✅ Created package.json" -ForegroundColor Green
}

# Step 2: Instructions for publishing
Write-Host ""
Write-Host "Step 2: Publish Shared Types" -ForegroundColor Yellow
Write-Host ""
Write-Host "To publish shared types as npm package:" -ForegroundColor Cyan
Write-Host "  1. cd shared/types" -ForegroundColor White
Write-Host "  2. npm install" -ForegroundColor White
Write-Host "  3. npm run build" -ForegroundColor White
Write-Host "  4. npm publish --access public" -ForegroundColor White
Write-Host ""
Write-Host "  Or for GitHub Packages:" -ForegroundColor Gray
Write-Host "  npm publish --registry=https://npm.pkg.github.com" -ForegroundColor Gray
Write-Host ""

# Step 3: Create frontend repo
Write-Host "Step 3: Create Frontend Repository" -ForegroundColor Yellow
Write-Host ""
Write-Host "Create a new repository on GitHub:" -ForegroundColor Cyan
Write-Host "  https://github.com/new" -ForegroundColor White
Write-Host ""
Write-Host "  Name: $FrontendRepoName" -ForegroundColor White
Write-Host "  Description: Credovo Platform Frontend (Lovable)" -ForegroundColor White
Write-Host "  Visibility: Public or Private" -ForegroundColor White
Write-Host ""

$createRepo = Read-Host "Have you created the repository? (y/n)"
if ($createRepo -ne "y") {
    Write-Host "Please create the repository first, then run this script again." -ForegroundColor Yellow
    exit
}

# Step 4: Initialize frontend repo
Write-Host ""
Write-Host "Step 4: Initialize Frontend Repository" -ForegroundColor Yellow
Write-Host ""
Write-Host "Run these commands:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  # Clone the new repo" -ForegroundColor Gray
Write-Host "  git clone https://github.com/AmanorsElliot/$FrontendRepoName.git" -ForegroundColor White
Write-Host "  cd $FrontendRepoName" -ForegroundColor White
Write-Host ""
Write-Host "  # Initialize npm" -ForegroundColor Gray
Write-Host "  npm init -y" -ForegroundColor White
Write-Host ""
Write-Host "  # Install shared types" -ForegroundColor Gray
Write-Host "  npm install @credovo/shared-types" -ForegroundColor White
Write-Host ""
Write-Host "  # Install React and other dependencies" -ForegroundColor Gray
Write-Host "  npm install react react-dom" -ForegroundColor White
Write-Host ""

# Step 5: Copy frontend code (if exists)
$frontendPath = Join-Path $BackendRepoPath "frontend\lovable-frontend"
if (Test-Path $frontendPath) {
    Write-Host "Step 5: Copy Existing Frontend Code" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "⚠️  Found existing frontend code at: $frontendPath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "You can copy it to the new repo:" -ForegroundColor Cyan
    Write-Host "  # After cloning credovo-frontend" -ForegroundColor Gray
    Write-Host "  cp -r $frontendPath/* credovo-frontend/" -ForegroundColor White
    Write-Host "  # Or manually copy files" -ForegroundColor Gray
    Write-Host ""
}

# Step 6: Connect Lovable
Write-Host "Step 6: Connect Lovable" -ForegroundColor Yellow
Write-Host ""
Write-Host "In Lovable:" -ForegroundColor Cyan
Write-Host "  1. Connect to GitHub" -ForegroundColor White
Write-Host "  2. Select repository: $FrontendRepoName" -ForegroundColor White
Write-Host "  3. Select branch: main (or create new branch)" -ForegroundColor White
Write-Host "  4. No restrictions needed - entire repo is frontend!" -ForegroundColor Green
Write-Host ""

# Step 7: Update backend CORS
Write-Host "Step 7: Update Backend CORS" -ForegroundColor Yellow
Write-Host ""
Write-Host "Update orchestration-service CORS to allow Lovable domain:" -ForegroundColor Cyan
Write-Host "  File: services/orchestration-service/src/index.ts" -ForegroundColor White
Write-Host ""
Write-Host "  const allowedOrigins = [" -ForegroundColor Gray
Write-Host "    'https://your-app.lovable.app'," -ForegroundColor White
Write-Host "    'http://localhost:3000'," -ForegroundColor White
Write-Host "  ];" -ForegroundColor Gray
Write-Host ""

# Summary
Write-Host "=== Summary ===" -ForegroundColor Green
Write-Host ""
Write-Host "✅ Separate repository is the SAFEST approach" -ForegroundColor Green
Write-Host "✅ Zero risk of overwriting backend files" -ForegroundColor Green
Write-Host "✅ Simpler Lovable integration" -ForegroundColor Green
Write-Host "✅ Independent versioning and deployment" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Publish @credovo/shared-types package" -ForegroundColor White
Write-Host "  2. Create credovo-frontend repository" -ForegroundColor White
Write-Host "  3. Initialize and install dependencies" -ForegroundColor White
Write-Host "  4. Connect Lovable to credovo-frontend" -ForegroundColor White
Write-Host "  5. Update backend CORS" -ForegroundColor White
Write-Host ""
Write-Host "See docs/LOVABLE_SEPARATE_REPO.md for detailed instructions." -ForegroundColor Gray
Write-Host ""

