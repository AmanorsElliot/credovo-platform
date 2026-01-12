# API Gateway Deployment Instructions

## Prerequisites

### Required Permissions

You need the following IAM role to deploy API Gateway:
- `roles/apigateway.admin` (API Gateway Admin)

Grant it with:
```powershell
gcloud projects add-iam-policy-binding credovo-eu-apps-nonprod `
    --member="user:$(gcloud config get-value account)" `
    --role="roles/apigateway.admin"
```

## Deployment Options

### Option 1: Use Deployment Script (Recommended)

```powershell
cd scripts
.\deploy-api-gateway.ps1
```

### Option 2: Manual Deployment

#### Step 1: Enable API Gateway API

```powershell
gcloud services enable apigateway.googleapis.com --project=credovo-eu-apps-nonprod
```

#### Step 2: Prepare OpenAPI Spec

```powershell
# Replace proxy service URL in OpenAPI spec
$openApiPath = "infrastructure\terraform\api-gateway-openapi.yaml"
$content = Get-Content $openApiPath -Raw
$content = $content -replace '\$\{proxy_service_url\}', 'https://proxy-service-saz24fo3sa-ew.a.run.app'
$content | Out-File -FilePath "$env:TEMP\api-gateway-openapi.yaml" -Encoding utf8
```

#### Step 3: Create API

```powershell
gcloud api-gateway apis create proxy-api `
    --project=credovo-eu-apps-nonprod `
    --display-name="Proxy Service API"
```

#### Step 4: Create API Config

```powershell
gcloud api-gateway api-configs create proxy-api-config `
    --api=proxy-api `
    --openapi-spec="$env:TEMP\api-gateway-openapi.yaml" `
    --project=credovo-eu-apps-nonprod `
    --backend-auth-service-account=proxy-service@credovo-eu-apps-nonprod.iam.gserviceaccount.com
```

#### Step 5: Create Gateway

```powershell
gcloud api-gateway gateways create proxy-gateway `
    --api=proxy-api `
    --api-config=proxy-api-config `
    --location=europe-west1 `
    --project=credovo-eu-apps-nonprod
```

#### Step 6: Get Gateway URL

```powershell
gcloud api-gateway gateways describe proxy-gateway `
    --location=europe-west1 `
    --project=credovo-eu-apps-nonprod `
    --format="value(defaultHostname)"
```

#### Step 7: Grant API Gateway Permission

```powershell
$projectNumber = (gcloud projects describe credovo-eu-apps-nonprod --format="value(projectNumber)")
$apiGatewaySA = "$projectNumber@cloudservices.gserviceaccount.com"

gcloud run services add-iam-policy-binding proxy-service `
    --region=europe-west1 `
    --member="serviceAccount:$apiGatewaySA" `
    --role=roles/run.invoker `
    --project=credovo-eu-apps-nonprod
```

## Testing

After deployment, test the API Gateway:

```powershell
$gatewayUrl = "https://<gateway-hostname>"
Invoke-RestMethod -Uri "$gatewayUrl/health" -Method GET
```

## Update Edge Function

Update your Supabase Edge Function to use the API Gateway URL:

```typescript
const apiGatewayUrl = Deno.env.get("API_GATEWAY_URL") || 
  "https://<gateway-hostname>";

const backendResponse = await fetch(`${apiGatewayUrl}/api/v1/applications`, {
  method: "POST",
  headers: {
    "Authorization": `Bearer ${token}`, // Supabase JWT
    "Content-Type": "application/json",
  },
  body: JSON.stringify(body),
});
```

## Note on Terraform

The Terraform provider (`hashicorp/google`) doesn't currently support API Gateway resources. Use gcloud commands or the deployment script instead.
