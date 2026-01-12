# API Gateway Deployment Complete ✅

## Deployment Status

✅ **API Gateway successfully deployed!**
- **URL**: `https://proxy-gateway-ayd13s2s.ew.gateway.dev`
- **State**: ACTIVE
- **Backend**: Orchestration Service (direct connection, no proxy needed)
- **Service Account**: `orchestration-service@credovo-eu-apps-nonprod.iam.gserviceaccount.com`
- **IAM Permission**: Granted ✅

## Architecture

```
Supabase Edge Function
    ↓ (Authorization: Bearer <Supabase JWT>)
API Gateway (publicly accessible)
    ↓ (authenticates via service account, forwards Supabase JWT in Authorization)
Proxy Service (Cloud Run - authenticated)
    ↓ (extracts Supabase JWT, forwards as X-User-Token)
    ↓ (uses own identity token in Authorization for Cloud Run IAM)
Orchestration Service (Cloud Run - authenticated)
    ↓ (validates Supabase JWT from X-User-Token header)
Application Logic
```

**Why Proxy Service?**
API Gateway overwrites the `Authorization` header with its identity token for Cloud Run IAM authentication. The proxy service extracts the original Supabase JWT and forwards it as `X-User-Token`, while using its own identity token for Cloud Run IAM. This preserves the Supabase JWT for the orchestration service to validate.

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

## Testing

After updating the Edge Function, test the full flow:
1. Edge Function calls API Gateway with Supabase JWT
2. API Gateway authenticates to orchestration service
3. Orchestration service validates Supabase JWT
4. Request succeeds

## Troubleshooting

If you get authentication errors:
1. Check proxy service logs: `gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=proxy-service" --limit=10 --project=credovo-eu-apps-nonprod`
2. Check orchestration service logs: `gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=orchestration-service" --limit=10 --project=credovo-eu-apps-nonprod`
3. Verify API Gateway IAM: `gcloud run services get-iam-policy proxy-service --region=europe-west1 --project=credovo-eu-apps-nonprod`
4. Verify proxy service IAM: `gcloud run services get-iam-policy orchestration-service --region=europe-west1 --project=credovo-eu-apps-nonprod`

## Summary

✅ API Gateway deployed and active  
✅ Points directly to orchestration service  
✅ IAM permissions configured  
⏭️ **Next**: Test and update Edge Function
