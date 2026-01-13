# API Gateway Host Field Fix

## Change Made

Updated the `host` field in the OpenAPI spec from a placeholder to the actual API Gateway hostname.

### Before
```yaml
host: orchestration-api-gateway
```

### After
```yaml
host: proxy-gateway-ayd13s2s.ew.gateway.dev
```

## Why This Matters

In Swagger 2.0, the `host` field should match the actual hostname of the API Gateway. If it doesn't match, API Gateway may:
- Reject requests that don't match the host
- Have routing issues
- Return 400 errors for mismatched hosts

## Expected Impact

If this was the issue:
- ✅ GET requests should now work
- ✅ All requests should route correctly
- ✅ No more 400 errors from host mismatch

## Testing

After deployment, test:
```powershell
# Should return 200 or 401 (not 400)
Invoke-WebRequest -Uri "https://proxy-gateway-ayd13s2s.ew.gateway.dev/api/v1/health" -Method GET
```

## Status

⏳ **Awaiting test results** from deployment
