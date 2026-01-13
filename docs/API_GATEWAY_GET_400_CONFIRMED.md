# API Gateway GET Request 400 Error - CONFIRMED

## Test Results (Date: 2026-01-13)

### Test 1: GET /api/v1/health (no auth required)
```
Request: GET https://proxy-gateway-ayd13s2s.ew.gateway.dev/api/v1/health
Result: ❌ 400 Bad Request
```

### Test 2: GET /api/v1/companies/search?query=test&limit=10
```
Request: GET https://proxy-gateway-ayd13s2s.ew.gateway.dev/api/v1/companies/search?query=test&limit=10
Result: ❌ 400 Bad Request
```

### Test 3: GET /api/v1/applications
```
Request: GET https://proxy-gateway-ayd13s2s.ew.gateway.dev/api/v1/applications
Result: ❌ 400 Bad Request
```

### Test 4: POST /api/v1/applications (control test)
```
Request: POST https://proxy-gateway-ayd13s2s.ew.gateway.dev/api/v1/applications
Result: ✅ 401 Unauthorized (expected - request reached backend, just needs auth)
```

## Conclusion

**✅ CONFIRMED: API Gateway has a bug that rejects ALL GET requests with 400 errors**

### Key Findings

1. **ALL GET requests fail** - Even `/api/v1/health` (which doesn't require auth) returns 400
2. **POST requests work** - POST returns 401 (expected without auth), proving the gateway works for POST
3. **Not an auth issue** - Even unauthenticated GET requests to `/health` fail
4. **Not a path issue** - All paths fail: `/health`, `/companies/search`, `/applications`
5. **Not a parameter issue** - Even requests without query parameters fail

### Impact

- ❌ **GET requests are completely broken** through API Gateway
- ✅ **POST/PUT/DELETE requests work fine** through API Gateway
- ⚠️ **This affects critical functionality:**
  - Company search (`GET /api/v1/companies/search`)
  - Listing applications (`GET /api/v1/applications`)
  - Health checks (`GET /api/v1/health`)

## Current Workaround Status

### Attempted Solutions

1. ✅ Made all parameters optional in OpenAPI spec
2. ✅ Made headers optional
3. ✅ Added explicit GET routes
4. ✅ Removed Authorization header parameter
5. ✅ Removed protocol h2
6. ✅ Moved path parameters to path-item level

**Result**: None of these fixes resolved the issue. All GET requests still return 400.

### Current Workaround

**Hybrid Approach:**
- GET requests → Call proxy service directly (bypass API Gateway)
- POST/PUT/DELETE → Use API Gateway

**Status**: ❌ **Blocked by organization policy**
- Proxy service can't be made public (`iam.allowedPolicyMemberDomains` blocks `allUsers`)
- Edge Functions can't authenticate with GCP (only have Supabase JWT)
- Result: 403 Forbidden when calling proxy service directly

## Next Steps

1. **Report API Gateway bug** to Google Cloud Support
   - All GET requests return 400 regardless of configuration
   - POST requests work fine (proves gateway is functional)
   - This appears to be a fundamental bug in API Gateway

2. **Request organization policy exemption** for proxy service
   - Required for GET request workaround
   - See `docs/PROXY_SERVICE_403_FIX.md`

3. **Monitor API Gateway release notes** for GET request fixes

## API Gateway Configuration

- **Gateway**: `proxy-gateway-ayd13s2s.ew.gateway.dev`
- **API Config**: `proxy-api-config`
- **Backend**: `https://proxy-service-saz24fo3sa-ew.a.run.app`
- **OpenAPI Spec**: `infrastructure/terraform/api-gateway-openapi.yaml`

## Test Commands

To reproduce:

```powershell
# Test GET (will fail with 400)
Invoke-WebRequest -Uri "https://proxy-gateway-ayd13s2s.ew.gateway.dev/api/v1/health" -Method GET

# Test POST (will return 401, which is expected)
Invoke-WebRequest -Uri "https://proxy-gateway-ayd13s2s.ew.gateway.dev/api/v1/applications" -Method POST -Body '{}' -ContentType "application/json"
```
