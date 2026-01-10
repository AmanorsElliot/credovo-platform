# Setup script to create a safe branch for Lovable frontend development
# This prevents Lovable from overwriting backend/infrastructure files

param(
    [string]$BranchName = "frontend/lovable"
)

$ErrorActionPreference = "Stop"

Write-Host "=== Setting Up Lovable Branch ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "This will create a separate branch for Lovable frontend development" -ForegroundColor Yellow
Write-Host "to protect your backend services and infrastructure." -ForegroundColor Yellow
Write-Host ""

# Check if branch already exists
$existingBranch = git branch -a | Select-String -Pattern $BranchName

if ($existingBranch) {
    Write-Host "⚠️  Branch '$BranchName' already exists" -ForegroundColor Yellow
    $continue = Read-Host "Continue anyway? (y/n)"
    if ($continue -ne "y") {
        exit
    }
}

# Ensure we're on main and up to date
Write-Host "Updating main branch..." -ForegroundColor Yellow
git checkout main
git pull origin main

# Create and checkout new branch
Write-Host "Creating branch: $BranchName" -ForegroundColor Yellow
git checkout -b $BranchName

# Push branch to remote
Write-Host "Pushing branch to GitHub..." -ForegroundColor Yellow
git push -u origin $BranchName

Write-Host ""
Write-Host "✅ Branch created successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. In Lovable, connect to GitHub" -ForegroundColor White
Write-Host "  2. Select branch: $BranchName" -ForegroundColor White
Write-Host "  3. Set root directory to: frontend/lovable-frontend" -ForegroundColor White
Write-Host "  4. Make a test change to verify it only touches frontend/" -ForegroundColor White
Write-Host ""
Write-Host "To merge changes back to main:" -ForegroundColor Yellow
Write-Host "  git checkout main" -ForegroundColor Gray
Write-Host "  git merge $BranchName" -ForegroundColor Gray
Write-Host "  git push origin main" -ForegroundColor Gray
Write-Host ""
Write-Host "Or create a Pull Request for review:" -ForegroundColor Yellow
Write-Host "  https://github.com/AmanorsElliot/credovo-platform/compare/main...$BranchName" -ForegroundColor Gray
Write-Host ""

