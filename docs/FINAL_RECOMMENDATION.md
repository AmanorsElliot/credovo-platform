# Final Recommendation: API Gateway Required

## Test Result

❌ **Direct public access is still blocked**:
```
ERROR: One or more users named in the policy do not belong to a permitted customer,
perhaps due to an organization policy.
```

The `iam.allowedPolicyMemberDomains` organization policy still blocks `allUsers` on Cloud Run services.

## Recommendation: Use API Gateway

Since direct public access is blocked, **API Gateway is the correct solution**.

### Why API Gateway is Best Practice Here

1. **Works around organization policy**: API Gateway doesn't require `allUsers` on Cloud Run
2. **Proper architecture**: API Gateway is designed for this exact use case
3. **Future-proof**: Provides API management features you may need later
4. **Security**: Maintains proper authentication boundaries

### Architecture

```
Supabase Edge Function
    ↓ (HTTPS - public, with Supabase JWT)
API Gateway (publicly accessible, no org policy restrictions)
    ↓ (authenticates automatically to Cloud Run via service account)
Proxy Service (Cloud Run - authenticated, no allUsers needed)
    ↓ (service account auth, forwards Supabase JWT)
Orchestration Service (Cloud Run - authenticated)
```

## Next Steps

### 1. Deploy API Gateway

```powershell
cd infrastructure\terraform
terraform init
terraform apply -target=google_project_service.api_gateway_api `
    -target=google_api_gateway_api.proxy_api `
    -target=google_api_gateway_api_config.proxy_api_config `
    -target=google_api_gateway_gateway.proxy_gateway
```

### 2. Grant API Gateway Permission

```powershell
# Get API Gateway service account
$projectNumber = (gcloud projects describe credovo-eu-apps-nonprod --format="value(projectNumber)")
$apiGatewaySA = "$projectNumber@cloudservices.gserviceaccount.com"

# Grant permission to invoke proxy-service
gcloud run services add-iam-policy-binding proxy-service `
    --region=europe-west1 `
    --member="serviceAccount:$apiGatewaySA" `
    --role=roles/run.invoker `
    --project=credovo-eu-apps-nonprod
```

### 3. Get API Gateway URL

```powershell
cd infrastructure\terraform
terraform output api_gateway_url
```

### 4. Update Edge Function

Update your Supabase Edge Function to use the API Gateway URL instead of the proxy service URL directly.

## Summary

- ✅ **API Gateway is the right solution** - Works around organization policy
- ✅ **Best practice** - Proper architecture for API proxying
- ✅ **No direct access possible** - Organization policy blocks `allUsers`
- ✅ **Ready to deploy** - Terraform configuration already exists

Proceed with API Gateway deployment.
