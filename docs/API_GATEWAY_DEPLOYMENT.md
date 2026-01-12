# API Gateway Deployment Guide

## Overview

API Gateway provides public access to the proxy service, which forwards authenticated requests from Supabase Edge Functions to the orchestration service.

## Architecture

```
Supabase Edge Function
    ↓ (HTTPS - public, with Supabase JWT)
API Gateway (publicly accessible)
    ↓ (authenticates automatically to Cloud Run)
Proxy Service (Cloud Run - authenticated via service account)
    ↓ (forwards Supabase JWT)
Orchestration Service (Cloud Run - authenticated)
```

## Prerequisites

✅ **API Gateway enabled** at folder and project level  
✅ **Proxy service deployed** in Cloud Run  
✅ **Terraform configured** with API Gateway resources

## Deployment Steps

### Step 1: Enable API Gateway API

```powershell
gcloud services enable apigateway.googleapis.com --project=credovo-eu-apps-nonprod
```

### Step 2: Deploy API Gateway with Terraform

```powershell
cd infrastructure\terraform
terraform init
terraform plan -target=google_project_service.api_gateway_api `
    -target=google_api_gateway_api.proxy_api `
    -target=google_api_gateway_api_config.proxy_api_config `
    -target=google_api_gateway_gateway.proxy_gateway

terraform apply
```

### Step 3: Grant API Gateway Service Account Permission

API Gateway automatically creates a service account to authenticate to Cloud Run. Grant it permission:

```powershell
# Get the API Gateway service account (automatically created)
$projectNumber = (gcloud projects describe credovo-eu-apps-nonprod --format="value(projectNumber)")
$apiGatewaySA = "$projectNumber@cloudservices.gserviceaccount.com"

# Grant permission to invoke proxy service
gcloud run services add-iam-policy-binding proxy-service `
    --region=europe-west1 `
    --member="serviceAccount:$apiGatewaySA" `
    --role=roles/run.invoker `
    --project=credovo-eu-apps-nonprod
```

### Step 4: Get API Gateway URL

```powershell
cd infrastructure\terraform
terraform output api_gateway_url
```

### Step 5: Test API Gateway

```powershell
$apiGatewayUrl = terraform output -raw api_gateway_url
Invoke-RestMethod -Uri "$apiGatewayUrl/health"
```

### Step 6: Update Edge Function

Update your Supabase Edge Function (`supabase/functions/applications/index.ts`) to use the API Gateway URL:

```typescript
const apiGatewayUrl = Deno.env.get("API_GATEWAY_URL") || 
  "https://proxy-gateway-XXXXX-ew.a.run.app";

const backendResponse = await fetch(`${apiGatewayUrl}/api/v1/applications`, {
  method: "POST",
  headers: {
    "Authorization": `Bearer ${token}`, // Supabase JWT
    "Content-Type": "application/json",
  },
  body: JSON.stringify(body),
});
```

Set the environment variable in Supabase:
```powershell
# In Supabase dashboard or via CLI
supabase secrets set API_GATEWAY_URL=https://proxy-gateway-XXXXX-ew.a.run.app
```

## Configuration Files

- `infrastructure/terraform/api-gateway.tf` - Terraform configuration
- `infrastructure/terraform/api-gateway-openapi.yaml` - OpenAPI spec for routing

## Key Features

- ✅ **Automatic Authentication**: API Gateway automatically authenticates to Cloud Run using its service account
- ✅ **Public Access**: API Gateway is publicly accessible, no organization policy issues
- ✅ **EU Data Boundary Compliant**: API Gateway is allowed at folder and project level
- ✅ **No Load Balancer Issues**: Uses different authentication mechanism than Load Balancer

## Troubleshooting

### 403 Forbidden from API Gateway

Check that API Gateway service account has `roles/run.invoker` on proxy-service:
```powershell
gcloud run services get-iam-policy proxy-service --region=europe-west1 --project=credovo-eu-apps-nonprod
```

### API Gateway Not Deploying

Verify API Gateway is enabled in project policy:
```powershell
gcloud resource-manager org-policies describe gcp.restrictServiceUsage --project=credovo-eu-apps-nonprod --format="yaml" | Select-String "apigateway"
```

### OpenAPI Spec Errors

Check the OpenAPI spec format in `infrastructure/terraform/api-gateway-openapi.yaml`. Ensure:
- `swagger: '2.0'` format (not OpenAPI 3.0)
- `x-google-backend` configuration is correct
- `path_translation: APPEND_PATH_TO_ADDRESS` is set

## See Also

- [Policy Configuration](POLICY_CONFIGURATION.md) - Understanding organization policies
- [IAP vs API Gateway](IAP_VS_API_GATEWAY.md) - Why API Gateway was chosen
