# Deploy API Gateway for Proxy Service
# This script deploys API Gateway using gcloud commands since Terraform provider doesn't support it

param(
    [string]$ProjectId = "credovo-eu-apps-nonprod",
    [string]$Region = "europe-west1",
    [string]$ProxyServiceUrl = "https://proxy-service-saz24fo3sa-ew.a.run.app"
)

Write-Host "Deploying API Gateway for Proxy Service..." -ForegroundColor Green
Write-Host "Project: $ProjectId" -ForegroundColor Cyan
Write-Host "Region: $Region" -ForegroundColor Cyan
Write-Host "Proxy Service URL: $ProxyServiceUrl" -ForegroundColor Cyan
Write-Host ""

# Step 1: Enable API Gateway API
Write-Host "Step 1: Enabling API Gateway API..." -ForegroundColor Yellow
gcloud services enable apigateway.googleapis.com --project=$ProjectId
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
gcloud api-gateway apis create proxy-api `
    --project=$ProjectId `
    --display-name="Proxy Service API" `
    2>&1 | Tee-Object -Variable apiOutput

if ($LASTEXITCODE -ne 0) {
    if ($apiOutput -match "already exists") {
        Write-Host "API already exists, continuing..." -ForegroundColor Yellow
    } else {
        Write-Host "ERROR: Failed to create API. You may need 'API Gateway Admin' role." -ForegroundColor Red
        Write-Host "Run: gcloud projects add-iam-policy-binding $ProjectId --member='user:$(gcloud config get-value account)' --role='roles/apigateway.admin'" -ForegroundColor Yellow
        exit 1
    }
}

# Step 4: Create API Config
Write-Host "`nStep 4: Creating API Gateway configuration..." -ForegroundColor Yellow
gcloud api-gateway api-configs create proxy-api-config `
    --api=proxy-api `
    --openapi-spec=$tempOpenApiPath `
    --project=$ProjectId `
    --backend-auth-service-account=proxy-service@$ProjectId.iam.gserviceaccount.com `
    2>&1 | Tee-Object -Variable configOutput

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to create API config" -ForegroundColor Red
    Write-Host $configOutput
    exit 1
}

# Step 5: Create Gateway
Write-Host "`nStep 5: Creating API Gateway..." -ForegroundColor Yellow
gcloud api-gateway gateways create proxy-gateway `
    --api=proxy-api `
    --api-config=proxy-api-config `
    --location=$Region `
    --project=$ProjectId `
    2>&1 | Tee-Object -Variable gatewayOutput

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to create Gateway" -ForegroundColor Red
    Write-Host $gatewayOutput
    exit 1
}

# Step 6: Get Gateway URL
Write-Host "`nStep 6: Getting API Gateway URL..." -ForegroundColor Yellow
$gatewayUrl = gcloud api-gateway gateways describe proxy-gateway `
    --location=$Region `
    --project=$ProjectId `
    --format="value(defaultHostname)"

if ($gatewayUrl) {
    Write-Host "`n✅ API Gateway deployed successfully!" -ForegroundColor Green
    Write-Host "API Gateway URL: https://$gatewayUrl" -ForegroundColor Cyan
    Write-Host "`nNext steps:" -ForegroundColor Yellow
    Write-Host "1. Grant API Gateway service account permission to invoke proxy-service"
    Write-Host "2. Update Edge Function to use: https://$gatewayUrl"
} else {
    Write-Host "WARNING: Could not retrieve Gateway URL" -ForegroundColor Yellow
}

# Step 7: Grant API Gateway service account permission
Write-Host "`nStep 7: Granting API Gateway service account permission..." -ForegroundColor Yellow
$projectNumber = (gcloud projects describe $ProjectId --format="value(projectNumber)")
$apiGatewaySA = "$projectNumber@cloudservices.gserviceaccount.com"

gcloud run services add-iam-policy-binding proxy-service `
    --region=$Region `
    --member="serviceAccount:$apiGatewaySA" `
    --role=roles/run.invoker `
    --project=$ProjectId `
    2>&1 | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ API Gateway service account granted permission" -ForegroundColor Green
} else {
    Write-Host "WARNING: Failed to grant permission. You may need to do this manually:" -ForegroundColor Yellow
    Write-Host "gcloud run services add-iam-policy-binding proxy-service --region=$Region --member='serviceAccount:$apiGatewaySA' --role=roles/run.invoker --project=$ProjectId" -ForegroundColor Cyan
}

Write-Host "`n✅ Deployment complete!" -ForegroundColor Green
