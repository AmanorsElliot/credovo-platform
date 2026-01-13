# Deploy API Gateway for Orchestration Service
# This script deploys API Gateway using gcloud commands since Terraform provider doesn't support it
# API Gateway connects to proxy service, which handles Supabase JWT forwarding to orchestration service

param(
    [string]$ProjectId = "credovo-eu-apps-nonprod",
    [string]$Region = "europe-west1",
    [string]$ProxyServiceUrl = "https://proxy-service-saz24fo3sa-ew.a.run.app"
)

Write-Host "Deploying API Gateway for Orchestration Service (via Proxy Service)..." -ForegroundColor Green
Write-Host "Project: $ProjectId" -ForegroundColor Cyan
Write-Host "Region: $Region" -ForegroundColor Cyan
Write-Host "Proxy Service URL: $ProxyServiceUrl" -ForegroundColor Cyan
Write-Host ""

# Step 1: Enable API Gateway API
Write-Host "Step 1: Enabling API Gateway API..." -ForegroundColor Yellow
gcloud services enable apigateway.googleapis.com --project=$ProjectId 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to enable API Gateway API" -ForegroundColor Red
    exit 1
}

# Step 2: Prepare OpenAPI spec
Write-Host "`nStep 2: Preparing OpenAPI specification..." -ForegroundColor Yellow
$openApiPath = "$PSScriptRoot\..\infrastructure\terraform\api-gateway-openapi.yaml"
$tempOpenApiPath = "$env:TEMP\api-gateway-openapi-$(Get-Date -Format 'yyyyMMddHHmmss').yaml"

$openApiContent = Get-Content $openApiPath -Raw
$openApiContent = $openApiContent -replace '\$\{proxy_service_url\}', $ProxyServiceUrl
$openApiContent | Out-File -FilePath $tempOpenApiPath -Encoding utf8 -NoNewline

Write-Host "OpenAPI spec prepared at: $tempOpenApiPath" -ForegroundColor Green

# Step 3: Create API
Write-Host "`nStep 3: Creating API Gateway API..." -ForegroundColor Yellow
$apiOutput = gcloud api-gateway apis create proxy-api `
    --project=$ProjectId `
    --display-name="Orchestration Service API" `
    2>&1

if ($LASTEXITCODE -ne 0) {
    if ($apiOutput -match "already exists" -or $apiOutput -match "ALREADY_EXISTS") {
        Write-Host "API already exists, continuing..." -ForegroundColor Yellow
    } else {
        Write-Host "ERROR: Failed to create API. You may need 'API Gateway Admin' role." -ForegroundColor Red
        Write-Host "Run: gcloud projects add-iam-policy-binding $ProjectId --member='user:$(gcloud config get-value account)' --role='roles/apigateway.admin'" -ForegroundColor Yellow
        Write-Host "Output: $apiOutput" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "✅ API created successfully" -ForegroundColor Green
}

# Step 4: Create API Config
Write-Host "`nStep 4: Creating API Gateway configuration..." -ForegroundColor Yellow

# Use timestamped config name to force new revision
$configId = "proxy-api-config-$(Get-Date -Format 'yyyyMMddHHmmss')"
Write-Host "Using config ID: $configId (timestamped to force new revision)" -ForegroundColor Gray

# Verify variable substitution worked
Write-Host "Verifying variable substitution in OpenAPI spec..." -ForegroundColor Gray
$specCheck = Get-Content $tempOpenApiPath -Raw
if ($specCheck -match '\$\{proxy_service_url\}') {
    Write-Host "⚠️  WARNING: Found unsubstituted \${proxy_service_url} in spec!" -ForegroundColor Red
    Write-Host "Variable substitution may have failed" -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "✅ Variable substitution verified - all \${proxy_service_url} replaced" -ForegroundColor Green
}

# Check if old config exists and delete gateway if needed
$existingConfig = gcloud api-gateway api-configs describe proxy-api-config --api=proxy-api --project=$ProjectId --format="value(name)" 2>&1
if ($LASTEXITCODE -eq 0 -and -not $existingConfig.StartsWith("ERROR")) {
    Write-Host "Old config 'proxy-api-config' exists, deleting gateway first..." -ForegroundColor Yellow
    
    # Delete gateway first (it's using the old config)
    Write-Host "Deleting gateway..." -ForegroundColor Yellow
    $deleteGatewayOutput = gcloud api-gateway gateways delete proxy-gateway `
        --location=$Region `
        --project=$ProjectId `
        --quiet `
        2>&1
    
    if ($LASTEXITCODE -eq 0 -or $deleteGatewayOutput -match "not found") {
        Write-Host "Gateway deleted, waiting for cleanup..." -ForegroundColor Yellow
        Start-Sleep -Seconds 3
        
        # Delete old config
        Write-Host "Deleting old API config..." -ForegroundColor Yellow
        $deleteConfigOutput = gcloud api-gateway api-configs delete proxy-api-config `
            --api=proxy-api `
            --project=$ProjectId `
            --quiet `
            2>&1
        
        if ($LASTEXITCODE -ne 0 -and $deleteConfigOutput -notmatch "not found") {
            Write-Host "WARNING: Failed to delete old config, continuing anyway..." -ForegroundColor Yellow
        }
        Start-Sleep -Seconds 2
    } else {
        Write-Host "WARNING: Failed to delete gateway, continuing anyway..." -ForegroundColor Yellow
    }
}

# Create new config with timestamped name
# Note: We don't use --backend-auth-service-account because API Gateway's own
# service account (PROJECT_NUMBER@cloudservices.gserviceaccount.com) will authenticate
$configOutput = gcloud api-gateway api-configs create $configId `
    --api=proxy-api `
    --openapi-spec=$tempOpenApiPath `
    --project=$ProjectId `
    2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to create API config" -ForegroundColor Red
    Write-Host $configOutput
    exit 1
} else {
    Write-Host "✅ API config created successfully: $configId" -ForegroundColor Green
}

# Step 5: Create Gateway
Write-Host "`nStep 5: Creating API Gateway..." -ForegroundColor Yellow
$gatewayOutput = gcloud api-gateway gateways create proxy-gateway `
    --api=proxy-api `
    --api-config=$configId `
    --location=$Region `
    --project=$ProjectId `
    2>&1

if ($LASTEXITCODE -ne 0) {
    if ($gatewayOutput -match "already exists" -or $gatewayOutput -match "ALREADY_EXISTS") {
        Write-Host "Gateway already exists, continuing..." -ForegroundColor Yellow
    } else {
        Write-Host "ERROR: Failed to create Gateway" -ForegroundColor Red
        Write-Host $gatewayOutput
        exit 1
    }
} else {
    Write-Host "✅ Gateway created successfully" -ForegroundColor Green
}

# Step 6: Get Gateway URL
Write-Host "`nStep 6: Getting API Gateway URL..." -ForegroundColor Yellow
$gatewayUrl = gcloud api-gateway gateways describe proxy-gateway `
    --location=$Region `
    --project=$ProjectId `
    --format="value(defaultHostname)" `
    2>&1

if ($gatewayUrl -and -not $gatewayUrl.StartsWith("ERROR")) {
    Write-Host "`n✅ API Gateway deployed successfully!" -ForegroundColor Green
    Write-Host "API Gateway URL: https://$gatewayUrl" -ForegroundColor Cyan
    Write-Host "`nNext steps:" -ForegroundColor Yellow
    Write-Host "1. API Gateway service account permission will be granted in next step"
    Write-Host "2. Update Edge Function to use: https://$gatewayUrl"
} else {
    Write-Host "WARNING: Could not retrieve Gateway URL" -ForegroundColor Yellow
    Write-Host "Output: $gatewayUrl" -ForegroundColor Yellow
}

# Step 6.5: Verify deployed backend address
Write-Host "`nStep 6.5: Verifying deployed backend address..." -ForegroundColor Yellow
$deployedConfig = gcloud api-gateway api-configs describe $configId `
    --api=proxy-api `
    --project=$ProjectId `
    --format="yaml" `
    2>&1

if ($LASTEXITCODE -eq 0) {
    # Check if backend address is a real URL (not a variable)
    if ($deployedConfig -match 'address:\s*(https://[^\s]+)') {
        $backendAddress = $matches[1]
        Write-Host "✅ Backend address verified: $backendAddress" -ForegroundColor Green
        if ($backendAddress -match '\$\{') {
            Write-Host "⚠️  WARNING: Backend address contains unsubstituted variable!" -ForegroundColor Red
            Write-Host "This would cause 400 errors. Variable substitution may have failed." -ForegroundColor Yellow
        }
    } else {
        Write-Host "⚠️  Could not extract backend address from deployed config" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️  Could not verify deployed config (may need permissions)" -ForegroundColor Yellow
}

# Step 7: Grant API Gateway service account permission to proxy-service
Write-Host "`nStep 7: Granting API Gateway service account permission to proxy-service..." -ForegroundColor Yellow
$projectNumber = (gcloud projects describe $ProjectId --format="value(projectNumber)")
$apiGatewaySA = "$projectNumber@cloudservices.gserviceaccount.com"

$iamOutput = gcloud run services add-iam-policy-binding proxy-service `
    --region=$Region `
    --member="serviceAccount:$apiGatewaySA" `
    --role=roles/run.invoker `
    --project=$ProjectId `
    2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ API Gateway service account granted permission to proxy-service" -ForegroundColor Green
} else {
    if ($iamOutput -match "already exists" -or $iamOutput -match "already has") {
        Write-Host "✅ Permission already granted" -ForegroundColor Green
    } else {
        Write-Host "WARNING: Failed to grant permission. You may need to do this manually:" -ForegroundColor Yellow
        Write-Host "gcloud run services add-iam-policy-binding proxy-service --region=$Region --member='serviceAccount:$apiGatewaySA' --role=roles/run.invoker --project=$ProjectId" -ForegroundColor Cyan
        Write-Host "Output: $iamOutput" -ForegroundColor Yellow
    }
}

Write-Host "`n✅ Deployment complete!" -ForegroundColor Green
