# Check if services have been deployed with actual code (not placeholder)

param(
    [string]$ProjectId = "credovo-eu-apps-nonprod",
    [string]$Region = "europe-west1"
)

$ErrorActionPreference = "Continue"

Write-Host "=== Checking Deployment Status ===" -ForegroundColor Cyan
Write-Host "Project: $ProjectId" -ForegroundColor Gray
Write-Host "Region: $Region" -ForegroundColor Gray
Write-Host ""

# Check if authenticated
Write-Host "Checking authentication..." -ForegroundColor Yellow
try {
    $currentProject = gcloud config get-value project 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Not authenticated. Please run: gcloud auth login" -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ Authenticated to project: $currentProject" -ForegroundColor Green
} catch {
    Write-Host "❌ Authentication check failed. Please run: gcloud auth login" -ForegroundColor Red
    exit 1
}

Write-Host ""

$services = @(
    "orchestration-service",
    "kyc-kyb-service",
    "connector-service"
)

foreach ($service in $services) {
    Write-Host "--- Checking $service ---" -ForegroundColor Yellow
    
    try {
        # Get current image
        $image = gcloud run services describe $service `
            --region=$Region `
            --project=$ProjectId `
            --format="value(spec.template.spec.containers[0].image)" 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Current Image: $image" -ForegroundColor Cyan
            
            if ($image -eq "gcr.io/cloudrun/hello") {
                Write-Host "⚠️  Using placeholder image - code not deployed yet" -ForegroundColor Yellow
            } elseif ($image -like "*docker.pkg.dev*") {
                Write-Host "✅ Using Artifact Registry image - code is deployed!" -ForegroundColor Green
                
                # Get revision info
                $revisions = gcloud run revisions list `
                    --service=$service `
                    --region=$Region `
                    --project=$ProjectId `
                    --limit=1 `
                    --format="value(metadata.name,metadata.creationTimestamp)" 2>&1
                
                if ($revisions) {
                    Write-Host "Latest Revision: $($revisions.Split("`t")[0])" -ForegroundColor Gray
                    Write-Host "Created: $($revisions.Split("`t")[1])" -ForegroundColor Gray
                }
            } else {
                Write-Host "ℹ️  Using custom image: $image" -ForegroundColor Cyan
            }
            
            # Get service URL
            $url = gcloud run services describe $service `
                --region=$Region `
                --project=$ProjectId `
                --format="value(status.url)" 2>&1
            
            if ($url) {
                Write-Host "Service URL: $url" -ForegroundColor Gray
            }
        } else {
            Write-Host "❌ Failed to get service info" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ Error checking $service : $_" -ForegroundColor Red
    }
    
    Write-Host ""
}

# Check Artifact Registry for images
Write-Host "--- Checking Artifact Registry ---" -ForegroundColor Yellow
try {
    $imagePath = "$Region-docker.pkg.dev/$ProjectId/credovo-services/orchestration-service"
    $images = gcloud artifacts docker images list $imagePath `
        --limit=3 `
        --format='table(package,version,create_time)' 2>&1
    
    if ($LASTEXITCODE -eq 0 -and $images) {
        Write-Host "Recent images in Artifact Registry:" -ForegroundColor Cyan
        Write-Host $images -ForegroundColor Gray
    } else {
        Write-Host "⚠️  No images found in Artifact Registry yet" -ForegroundColor Yellow
    }
} catch {
    Write-Host "ℹ️  Could not check Artifact Registry (may need permissions)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "To check GitHub Actions status:" -ForegroundColor Yellow
Write-Host "1. Go to: https://github.com/AmanorsElliot/credovo-platform/actions" -ForegroundColor Cyan
Write-Host "2. Look for 'Deploy to Cloud Run' workflow" -ForegroundColor Cyan
Write-Host "3. Check if latest run completed successfully" -ForegroundColor Cyan
Write-Host ""
Write-Host "If services are still using placeholder images:" -ForegroundColor Yellow
Write-Host "- GitHub Actions may not have Workload Identity configured yet" -ForegroundColor Gray
Write-Host "- Or workflow may have failed - check Actions tab for errors" -ForegroundColor Gray
Write-Host "- See docs/DEPLOYMENT_READY.md for setup instructions" -ForegroundColor Gray

