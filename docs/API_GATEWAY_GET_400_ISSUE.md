# API Gateway GET Request 400 Error

## Problem

**ALL GET requests through API Gateway return 400 (Google HTML error page)**
- ❌ GET `/api/v1/companies/search?query=test&limit=10` → 400
- ❌ GET `/api/v1/applications` → 400
- ❌ GET `/api/v1/health` → 400
- ✅ POST `/api/v1/applications` → 401 (works, just needs auth)

## Root Cause

API Gateway is rejecting GET requests specifically, regardless of path or headers. This suggests an issue with:
1. How the catch-all pattern `/{path=**}` handles GET requests
2. Query parameter handling in GET requests
3. Path parameter extraction for GET requests

## Attempted Fixes

1. ✅ Made headers optional (`required: false`) - Still 400
2. ✅ Removed explicit `/api/v1/companies/search` path - Still 400
3. ✅ Verified backend address is correct (not self-call loop) - Confirmed
4. ✅ Tested proxy service directly - Works (returns 401, which is expected)

## Current OpenAPI Spec

```yaml
paths:
  /{path=**}:
    get:
      operationId: orchestrationGet
      parameters:
        - in: header
          name: Authorization
          type: string
          required: false  # Made optional
        - in: header
          name: X-Supabase-Token
          type: string
          required: false  # Made optional
        - name: path
          in: path
          required: true
          type: string
      x-google-backend:
        address: ${proxy_service_url}
        path_translation: APPEND_PATH_TO_ADDRESS
        protocol: h2
        jwt_audience: ${proxy_service_url}
```

## Next Steps to Investigate

1. **Check API Gateway logs** for specific error messages:
   ```powershell
   gcloud logging read "resource.type=api_gateway AND resource.labels.gateway_id=proxy-gateway" --limit=20 --project=credovo-eu-apps-nonprod
   ```

2. **Try removing the `path` parameter** from GET requests (might be causing validation issues)

3. **Try using `CONSTANT_ADDRESS` instead of `APPEND_PATH_TO_ADDRESS`** (though this would require proxy service routing changes)

4. **Check if API Gateway has issues with wildcard paths for GET requests** - might need explicit paths

5. **Verify the deployed OpenAPI spec** matches what we expect:
   ```powershell
   gcloud api-gateway api-configs describe proxy-api-config --api=proxy-api --project=credovo-eu-apps-nonprod --format="get(openapiFiles[0].contents)" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) } > deployed-spec.yaml
   ```

## Workaround

Until this is fixed, the frontend could:
1. Use POST requests instead of GET (if the backend supports it)
2. Call the proxy service directly (bypassing API Gateway)
3. Use a different API Gateway configuration
