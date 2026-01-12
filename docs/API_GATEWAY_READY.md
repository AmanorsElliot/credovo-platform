# API Gateway Ready for Deployment

## Policy Status

✅ **API Gateway enabled at folder level** (`eu-gdpr`)
✅ **API Gateway enabled at project level** (`credovo-eu-apps-nonprod`)
✅ **EU Data Boundary compliant** - No policy violations

## Current Project Policy

The project policy now includes:
- ✅ `apigateway.googleapis.com` - **Enabled for API Gateway**
- ✅ All other required services
- ✅ Compliant with folder-level policy

## Next Steps: Deploy API Gateway

### Step 1: Verify API Gateway API is Enabled

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

API Gateway needs permission to invoke the proxy service:

```powershell
# Get the API Gateway service account (automatically created)
$projectNumber = (gcloud projects describe credovo-eu-apps-nonprod --format="value(projectNumber)")
$apiGatewaySA = "$projectNumber@cloudservices.gserviceaccount.com"

# Grant permission
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

Update your Supabase Edge Function to use the API Gateway URL:

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

## Configuration Files

- ✅ `infrastructure/terraform/api-gateway.tf` - Terraform configuration
- ✅ `infrastructure/terraform/api-gateway-openapi.yaml` - OpenAPI spec
- ✅ `infrastructure/terraform/org-policy-exemption.json` - Updated with API Gateway

## Notes

- API Gateway automatically authenticates to Cloud Run using its service account
- No Load Balancer authentication issues
- Public access through API Gateway, private Cloud Run service
- EU Data Boundary compliant
