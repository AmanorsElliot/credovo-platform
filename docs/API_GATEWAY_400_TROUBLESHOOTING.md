# API Gateway 400 Error Troubleshooting

## Problem

API Gateway returns Google HTML 400 error for paths starting with `/api/v1/`, but `/health` works fine.

## Root Cause Analysis

- ✅ `/health` works (200 OK)
- ❌ `/api/v1/health` returns 400 (Google HTML error page)
- ❌ `/api/v1/companies/search?query=test&limit=10` returns 400

This suggests the `/{path=**}` catch-all pattern is not matching paths that start with `/api/v1/`.

## Possible Solutions

### 1. Check Path Pattern Syntax

The `/{path=**}` pattern should match all paths, but API Gateway might have issues with:
- Paths starting with `/api/`
- Query parameters
- Multiple path segments

### 2. Verify Backend Address

Ensure the backend address is correct:
- Should be: `https://proxy-service-saz24fo3sa-ew.a.run.app`
- NOT: `https://proxy-gateway-ayd13s2s.ew.gateway.dev` (self-call loop)

### 3. Check Path Translation

Current setting: `APPEND_PATH_TO_ADDRESS`

For a request to `/api/v1/companies/search?query=test`:
- Backend address: `https://proxy-service-saz24fo3sa-ew.a.run.app`
- Final URL should be: `https://proxy-service-saz24fo3sa-ew.a.run.app/api/v1/companies/search?query=test`

### 4. Test Direct Proxy Service Access

```powershell
$proxyUrl = "https://proxy-service-saz24fo3sa-ew.a.run.app"
Invoke-WebRequest -Uri "$proxyUrl/api/v1/companies/search?query=test&limit=10" `
    -Method GET `
    -Headers @{ "Authorization" = "Bearer test"; "X-Supabase-Token" = "test" }
```

If this works, the issue is with API Gateway routing, not the proxy service.

### 5. Alternative: Use CONSTANT_ADDRESS

If `APPEND_PATH_TO_ADDRESS` is causing issues, try `CONSTANT_ADDRESS` and handle routing in the proxy service:

```yaml
x-google-backend:
  address: ${proxy_service_url}
  path_translation: CONSTANT_ADDRESS
```

But this would require the proxy service to handle all routing, which defeats the purpose.

## Next Steps

1. Verify the deployed OpenAPI spec has the correct backend address
2. Check API Gateway logs for routing errors
3. Test with a simpler path pattern (e.g., `/api/**` instead of `/{path=**}`)
4. Consider using explicit paths for known endpoints instead of catch-all
