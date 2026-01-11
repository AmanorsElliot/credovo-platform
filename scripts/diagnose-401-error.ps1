# Diagnostic Script for 401 Unauthorized Error
# This script checks all components of the authentication flow

param(
    [string]$ProjectId = "credovo-eu-apps-nonprod",
    [string]$Region = "europe-west1",
    [string]$SupabaseToken = ""
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "401 Unauthorized Error Diagnostic Tool" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$errors = @()
$warnings = @()
$success = @()

# Step 1: Check Proxy Service
Write-Host "Step 1: Checking Proxy Service..." -ForegroundColor Yellow
try {
    $proxyService = gcloud run services describe proxy-service `
        --region=$Region `
        --project=$ProjectId `
        --format=json 2>&1 | ConvertFrom-Json
    
    if ($proxyService) {
        $proxyUrl = $proxyService.status.url
        Write-Host "  ✅ Proxy service found: $proxyUrl" -ForegroundColor Green
        $success += "Proxy service deployed at $proxyUrl"
        
        # Check if it's public
        $iamPolicy = gcloud run services get-iam-policy proxy-service `
            --region=$Region `
            --project=$ProjectId `
            --format=json 2>&1 | ConvertFrom-Json
        
        $hasPublicAccess = $iamPolicy.bindings | Where-Object { 
            $_.role -eq "roles/run.invoker" -and $_.members -contains "allUsers" 
        }
        
        if ($hasPublicAccess) {
            Write-Host "  ✅ Proxy service is publicly accessible" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️  Proxy service is NOT publicly accessible" -ForegroundColor Yellow
            $warnings += "Proxy service should be public (allUsers) for Edge Functions"
        }
        
        # Test health endpoint
        try {
            $healthResponse = Invoke-RestMethod -Uri "$proxyUrl/health" -TimeoutSec 5
            Write-Host "  ✅ Proxy service health check passed" -ForegroundColor Green
        } catch {
            Write-Host "  ❌ Proxy service health check failed: $($_.Exception.Message)" -ForegroundColor Red
            $errors += "Proxy service health check failed"
        }
    }
} catch {
    Write-Host "  ❌ Proxy service not found or not accessible" -ForegroundColor Red
    Write-Host "     Error: $($_.Exception.Message)" -ForegroundColor Red
    $errors += "Proxy service not deployed. See docs/PROXY_SERVICE_SETUP.md"
}

Write-Host ""

# Step 2: Check Orchestration Service Configuration
Write-Host "Step 2: Checking Orchestration Service Configuration..." -ForegroundColor Yellow
try {
    $orchestrationService = gcloud run services describe orchestration-service `
        --region=$Region `
        --project=$ProjectId `
        --format=json 2>&1 | ConvertFrom-Json
    
    if ($orchestrationService) {
        $orchestrationUrl = $orchestrationService.status.url
        Write-Host "  ✅ Orchestration service found: $orchestrationUrl" -ForegroundColor Green
        
        # Check environment variables
        $envVars = $orchestrationService.spec.template.spec.containers[0].env
        $hasSupabaseUrl = $envVars | Where-Object { $_.name -eq "SUPABASE_URL" }
        $hasSupabaseJwks = $envVars | Where-Object { $_.name -eq "SUPABASE_JWKS_URI" }
        
        if ($hasSupabaseUrl -or $hasSupabaseJwks) {
            Write-Host "  ✅ Supabase authentication configured" -ForegroundColor Green
            if ($hasSupabaseUrl) {
                Write-Host "     SUPABASE_URL: $($hasSupabaseUrl.value)" -ForegroundColor Gray
            }
            if ($hasSupabaseJwks) {
                Write-Host "     SUPABASE_JWKS_URI: $($hasSupabaseJwks.value)" -ForegroundColor Gray
            }
        } else {
            Write-Host "  ❌ Supabase authentication NOT configured" -ForegroundColor Red
            Write-Host "     Missing: SUPABASE_URL or SUPABASE_JWKS_URI" -ForegroundColor Red
            $errors += "Orchestration service missing SUPABASE_URL or SUPABASE_JWKS_URI"
        }
    }
} catch {
    Write-Host "  ❌ Orchestration service not found" -ForegroundColor Red
    $errors += "Orchestration service not accessible"
}

Write-Host ""

# Step 3: Check Service Account Permissions
Write-Host "Step 3: Checking Service Account Permissions..." -ForegroundColor Yellow
try {
    $iamPolicy = gcloud run services get-iam-policy orchestration-service `
        --region=$Region `
        --project=$ProjectId `
        --format=json 2>&1 | ConvertFrom-Json
    
    $proxyServiceAccount = "serviceAccount:proxy-service@$ProjectId.iam.gserviceaccount.com"
    $hasAccess = $iamPolicy.bindings | Where-Object { 
        $_.role -eq "roles/run.invoker" -and $_.members -contains $proxyServiceAccount 
    }
    
    if ($hasAccess) {
        Write-Host "  ✅ Proxy service account has access to orchestration service" -ForegroundColor Green
        $success += "Service account permissions configured correctly"
    } else {
        Write-Host "  ❌ Proxy service account does NOT have access" -ForegroundColor Red
        Write-Host "     Missing: $proxyServiceAccount with role roles/run.invoker" -ForegroundColor Red
        $errors += "Proxy service account needs roles/run.invoker on orchestration service"
    }
} catch {
    Write-Host "  ⚠️  Could not check IAM policy: $($_.Exception.Message)" -ForegroundColor Yellow
    $warnings += "Could not verify service account permissions"
}

Write-Host ""

# Step 4: Check Recent Logs
Write-Host "Step 4: Checking Recent Orchestration Service Logs..." -ForegroundColor Yellow
try {
    $logs = gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=orchestration-service AND (textPayload=~'Auth middleware selected' OR textPayload=~'JWT' OR textPayload=~'Missing token' OR textPayload=~'Unauthorized')" `
        --limit 10 `
        --format json `
        --project=$ProjectId 2>&1 | ConvertFrom-Json
    
    if ($logs) {
        $authMiddlewareLog = $logs | Where-Object { $_.textPayload -like "*Auth middleware selected*" } | Select-Object -First 1
        if ($authMiddlewareLog) {
            if ($authMiddlewareLog.textPayload -like "*Supabase*") {
                Write-Host "  ✅ Auth middleware is set to Supabase" -ForegroundColor Green
            } else {
                Write-Host "  ⚠️  Auth middleware is set to Backend (not Supabase)" -ForegroundColor Yellow
                $warnings += "Orchestration service using Backend auth instead of Supabase"
            }
        }
        
        $errorLogs = $logs | Where-Object { 
            $_.textPayload -like "*Missing token*" -or 
            $_.textPayload -like "*Unauthorized*" -or 
            $_.textPayload -like "*JWT validation failed*" 
        }
        
        if ($errorLogs) {
            Write-Host "  ⚠️  Found authentication errors in recent logs:" -ForegroundColor Yellow
            $errorLogs | Select-Object -First 3 | ForEach-Object {
                Write-Host "     $($_.textPayload.Substring(0, [Math]::Min(100, $_.textPayload.Length)))" -ForegroundColor Gray
            }
        } else {
            Write-Host "  ✅ No recent authentication errors found" -ForegroundColor Green
        }
    } else {
        Write-Host "  ⚠️  No recent logs found" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ⚠️  Could not read logs: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""

# Step 5: Test with Token (if provided)
if ($SupabaseToken) {
    Write-Host "Step 5: Testing with Supabase Token..." -ForegroundColor Yellow
    if ($proxyUrl) {
        try {
            $testResponse = Invoke-RestMethod -Uri "$proxyUrl/api/v1/applications" `
                -Method POST `
                -Headers @{
                    "Authorization" = "Bearer $SupabaseToken"
                    "Content-Type" = "application/json"
                } `
                -Body (@{
                    type = "business_mortgage"
                    data = @{}
                } | ConvertTo-Json) `
                -ErrorAction Stop
            
            Write-Host "  ✅ Test request succeeded!" -ForegroundColor Green
            Write-Host "     Response: $($testResponse | ConvertTo-Json -Compress)" -ForegroundColor Gray
            $success += "End-to-end test passed"
        } catch {
            Write-Host "  ❌ Test request failed: $($_.Exception.Message)" -ForegroundColor Red
            if ($_.ErrorDetails.Message) {
                Write-Host "     Details: $($_.ErrorDetails.Message)" -ForegroundColor Red
            }
            $errors += "End-to-end test failed: $($_.Exception.Message)"
        }
    } else {
        Write-Host "  ⚠️  Skipping test (proxy service URL not available)" -ForegroundColor Yellow
    }
} else {
    Write-Host "Step 5: Skipping token test (no token provided)" -ForegroundColor Yellow
    Write-Host "  To test with a token, run: .\scripts\diagnose-401-error.ps1 -SupabaseToken 'your-token'" -ForegroundColor Gray
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if ($success.Count -gt 0) {
    Write-Host "`n✅ Successes:" -ForegroundColor Green
    $success | ForEach-Object { Write-Host "   - $_" -ForegroundColor Gray }
}

if ($warnings.Count -gt 0) {
    Write-Host "`n⚠️  Warnings:" -ForegroundColor Yellow
    $warnings | ForEach-Object { Write-Host "   - $_" -ForegroundColor Gray }
}

if ($errors.Count -gt 0) {
    Write-Host "`n❌ Errors:" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host "   - $_" -ForegroundColor Gray }
    Write-Host "`n📖 See docs/DIAGNOSE_401_ERROR.md for solutions" -ForegroundColor Cyan
    exit 1
} else {
    Write-Host "`n✅ All checks passed! If you're still seeing 401 errors:" -ForegroundColor Green
    Write-Host "   1. Verify Edge Function is using PROXY_SERVICE_URL" -ForegroundColor Gray
    Write-Host "   2. Check Edge Function logs in Supabase dashboard" -ForegroundColor Gray
    Write-Host "   3. Verify Supabase JWT token is valid and not expired" -ForegroundColor Gray
    exit 0
}
