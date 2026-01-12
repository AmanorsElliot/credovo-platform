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
    ↓ (authenticates via service account, forwards Supabase JWT)
Orchestration Service (Cloud Run - authenticated)
    ↓ (validates Supabase JWT from Authorization header)
Application Logic
```

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

## Important Note: Header Transformation

**Current Status**: API Gateway points directly to orchestration service.

**Potential Issue**: API Gateway will add `Authorization: Bearer <identity-token>` for Cloud Run IAM, which might overwrite the original `Authorization: Bearer <Supabase JWT>` header.

**Solution**: The orchestration service checks `X-User-Token` header first, then falls back to `Authorization` header. If API Gateway doesn't preserve the original Authorization header, we may need to:
1. Keep the proxy service (it handles header transformation)
2. Or configure API Gateway to forward Authorization as X-User-Token (if supported)

## Testing

After updating the Edge Function, test the full flow:
1. Edge Function calls API Gateway with Supabase JWT
2. API Gateway authenticates to orchestration service
3. Orchestration service validates Supabase JWT
4. Request succeeds

## If It Doesn't Work

If you get authentication errors, it means API Gateway isn't preserving the Supabase JWT header. In that case:
- Keep the proxy service
- Point API Gateway back to proxy service
- Proxy service handles the header transformation

## Summary

✅ API Gateway deployed and active  
✅ Points directly to orchestration service  
✅ IAM permissions configured  
⏭️ **Next**: Test and update Edge Function
