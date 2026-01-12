# API Gateway Deployment Complete ✅

## Deployment Status

✅ **API Gateway successfully deployed and working!**
- **URL**: `https://proxy-gateway-ayd13s2s.ew.gateway.dev`
- **State**: ACTIVE
- **Backend**: Proxy Service (handles Supabase JWT forwarding)
- **Service Account**: `858440156644@cloudservices.gserviceaccount.com` (API Gateway's own service account)
- **IAM Permission**: Granted ✅
- **Health Check**: ✅ Working

## Architecture

```
Supabase Edge Function
    ↓ (Authorization: Bearer <Supabase JWT>)
API Gateway (publicly accessible)
    ↓ (authenticates via own service account, forwards Supabase JWT in Authorization)
Proxy Service (Cloud Run - authenticated)
    ↓ (extracts Supabase JWT, forwards as X-User-Token)
    ↓ (uses own identity token in Authorization for Cloud Run IAM)
Orchestration Service (Cloud Run - authenticated)
    ↓ (validates Supabase JWT from X-User-Token header)
Application Logic
```

**Why Proxy Service?**
API Gateway overwrites the `Authorization` header with its identity token for Cloud Run IAM authentication. The proxy service extracts the original Supabase JWT and forwards it as `X-User-Token`, while using its own identity token for Cloud Run IAM. This preserves the Supabase JWT for the orchestration service to validate.

## Configuration Details

### API Gateway Configuration
- **API**: `proxy-api`
- **Config**: `proxy-api-config`
- **Gateway**: `proxy-gateway` (location: `europe-west1`)
- **Backend**: `https://proxy-service-saz24fo3sa-ew.a.run.app`
- **Authentication**: API Gateway uses its own service account (`PROJECT_NUMBER@cloudservices.gserviceaccount.com`)

### IAM Permissions
- API Gateway service account (`858440156644@cloudservices.gserviceaccount.com`) has `roles/run.invoker` on proxy-service
- Proxy service service account has `roles/run.invoker` on orchestration-service

## Next Steps

### 1. Test API Gateway

```powershell
$gatewayUrl = "https://proxy-gateway-ayd13s2s.ew.gateway.dev"

# Test health endpoint
Invoke-RestMethod -Uri "$gatewayUrl/health" -Method GET

# Test with Supabase JWT (if you have one)
$supabaseToken = "<your-supabase-jwt>"
Invoke-RestMethod -Uri "$gatewayUrl/api/v1/applications" `
    -Method GET `
    -Headers @{ "Authorization" = "Bearer $supabaseToken" }
```

### 2. Update Edge Function

Update your Supabase Edge Function (`supabase/functions/applications/index.ts`):

```typescript
const apiGatewayUrl = Deno.env.get("API_GATEWAY_URL") || 
  "https://proxy-gateway-ayd13s2s.ew.gateway.dev";

const backendResponse = await fetch(`${apiGatewayUrl}/api/v1/applications`, {
  method: "POST",
  headers: {
    "Authorization": `Bearer ${token}`, // Supabase JWT
    "Content-Type": "application/json",
  },
  body: JSON.stringify(body),
});
```

### 3. Set Environment Variable in Supabase

```powershell
# In Supabase dashboard or via CLI
supabase secrets set API_GATEWAY_URL=https://proxy-gateway-ayd13s2s.ew.gateway.dev
```

## Header Transformation

**Solution Implemented**: API Gateway points to proxy service, which handles header transformation:

1. **API Gateway** → Receives Supabase JWT in `Authorization` header
2. **API Gateway** → Adds its own identity token to `Authorization` (overwrites original)
3. **Proxy Service** → Extracts original Supabase JWT from `Authorization` before it was overwritten
4. **Proxy Service** → Forwards Supabase JWT as `X-User-Token` to orchestration service
5. **Proxy Service** → Uses its own identity token in `Authorization` for Cloud Run IAM
6. **Orchestration Service** → Reads Supabase JWT from `X-User-Token` header (prioritized)

## Troubleshooting

If you get authentication errors:
1. Check proxy service logs: `gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=proxy-service" --limit=10 --project=credovo-eu-apps-nonprod`
2. Check orchestration service logs: `gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=orchestration-service" --limit=10 --project=credovo-eu-apps-nonprod`
3. Verify API Gateway IAM: `gcloud run services get-iam-policy proxy-service --region=europe-west1 --project=credovo-eu-apps-nonprod`
4. Verify proxy service IAM: `gcloud run services get-iam-policy orchestration-service --region=europe-west1 --project=credovo-eu-apps-nonprod`

## Important Notes

- **No `backend-auth-service-account`**: API Gateway uses its own service account for authentication. The `backend-auth-service-account` parameter was removed because it was causing authentication issues.
- **Health endpoint works**: The `/health` endpoint is accessible and returns `{"status": "healthy", "service": "proxy-service"}`.
- **Proxy service required**: Due to API Gateway's header overwriting behavior, the proxy service is necessary to preserve the Supabase JWT.

## Summary

✅ API Gateway deployed and active  
✅ Points to proxy service (handles header transformation)  
✅ IAM permissions configured  
✅ Health check working  
⏭️ **Next**: Update Edge Function to use API Gateway URL
