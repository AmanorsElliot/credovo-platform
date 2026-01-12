# Deploy API Gateway for Orchestration Service
# This script deploys API Gateway using gcloud commands since Terraform provider doesn't support it
# API Gateway connects directly to orchestration service, eliminating the need for proxy service

param(
    [string]$ProjectId = "credovo-eu-apps-nonprod",
    [string]$Region = "europe-west1",
    [string]$OrchestrationServiceUrl = "https://orchestration-service-saz24fo3sa-ew.a.run.app"
)

Write-Host "Deploying API Gateway for Orchestration Service..." -ForegroundColor Green
Write-Host "Project: $ProjectId" -ForegroundColor Cyan
Write-Host "Region: $Region" -ForegroundColor Cyan
Write-Host "Orchestration Service URL: $OrchestrationServiceUrl" -ForegroundColor Cyan
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
$openApiContent = $openApiContent -replace '\$\{orchestration_service_url\}', $OrchestrationServiceUrl
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
$configOutput = gcloud api-gateway api-configs create proxy-api-config `
    --api=proxy-api `
    --openapi-spec=$tempOpenApiPath `
    --project=$ProjectId `
    --backend-auth-service-account=orchestration-service@$ProjectId.iam.gserviceaccount.com `
    2>&1

if ($LASTEXITCODE -ne 0) {
    if ($configOutput -match "already exists" -or $configOutput -match "ALREADY_EXISTS") {
        Write-Host "API config already exists, updating..." -ForegroundColor Yellow
        # Update existing config
        $updateOutput = gcloud api-gateway api-configs update proxy-api-config `
            --api=proxy-api `
            --openapi-spec=$tempOpenApiPath `
            --project=$ProjectId `
            --backend-auth-service-account=orchestration-service@$ProjectId.iam.gserviceaccount.com `
            2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ API config updated successfully" -ForegroundColor Green
        } else {
            Write-Host "WARNING: Failed to update API config, but it exists. Continuing..." -ForegroundColor Yellow
            Write-Host "Update output: $updateOutput" -ForegroundColor Yellow
        }
    } else {
        Write-Host "ERROR: Failed to create API config" -ForegroundColor Red
        Write-Host $configOutput
        exit 1
    }
} else {
    Write-Host "✅ API config created successfully" -ForegroundColor Green
}

# Step 5: Create Gateway
Write-Host "`nStep 5: Creating API Gateway..." -ForegroundColor Yellow
$gatewayOutput = gcloud api-gateway gateways create proxy-gateway `
    --api=proxy-api `
    --api-config=proxy-api-config `
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

# Step 7: Grant API Gateway service account permission to orchestration-service
Write-Host "`nStep 7: Granting API Gateway service account permission to orchestration-service..." -ForegroundColor Yellow
$projectNumber = (gcloud projects describe $ProjectId --format="value(projectNumber)")
$apiGatewaySA = "$projectNumber@cloudservices.gserviceaccount.com"

$iamOutput = gcloud run services add-iam-policy-binding orchestration-service `
    --region=$Region `
    --member="serviceAccount:$apiGatewaySA" `
    --role=roles/run.invoker `
    --project=$ProjectId `
    2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ API Gateway service account granted permission to orchestration-service" -ForegroundColor Green
} else {
    if ($iamOutput -match "already exists" -or $iamOutput -match "already has") {
        Write-Host "✅ Permission already granted" -ForegroundColor Green
    } else {
        Write-Host "WARNING: Failed to grant permission. You may need to do this manually:" -ForegroundColor Yellow
        Write-Host "gcloud run services add-iam-policy-binding orchestration-service --region=$Region --member='serviceAccount:$apiGatewaySA' --role=roles/run.invoker --project=$ProjectId" -ForegroundColor Cyan
        Write-Host "Output: $iamOutput" -ForegroundColor Yellow
    }
}

Write-Host "`n✅ Deployment complete!" -ForegroundColor Green
