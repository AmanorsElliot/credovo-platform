# Test Adding allUsers to Proxy Service IAM Policy
# This will show the exact error message from the organization policy

param(
    [string]$ProjectId = "credovo-eu-apps-nonprod",
    [string]$Region = "europe-west1"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Testing allUsers IAM Policy Binding" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Attempting to add allUsers to proxy-service..." -ForegroundColor Yellow
Write-Host "This will show the exact organization policy error if it fails." -ForegroundColor Gray
Write-Host ""

try {
    gcloud run services add-iam-policy-binding proxy-service `
        --region=$Region `
        --member="allUsers" `
        --role=roles/run.invoker `
        --project=$ProjectId
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✅ SUCCESS: allUsers was added successfully!" -ForegroundColor Green
        Write-Host "The proxy service should now be publicly accessible." -ForegroundColor Green
    }
} catch {
    Write-Host ""
    Write-Host "❌ ERROR: Failed to add allUsers" -ForegroundColor Red
    Write-Host ""
    Write-Host "Error details:" -ForegroundColor Yellow
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host "This error message contains the exact organization policy constraint" -ForegroundColor Gray
    Write-Host "that is blocking the operation. Use this information for your support request." -ForegroundColor Gray
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
