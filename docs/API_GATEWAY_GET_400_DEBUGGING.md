# API Gateway GET Request 400 Error - Debugging Log

## Problem
**ALL GET requests through API Gateway return 400 (Google HTML error page)**
- ❌ GET `/api/v1/companies/search?query=test&limit=10` → 400
- ❌ GET `/api/v1/applications` → 400
- ❌ GET `/api/v1/health` → 400
- ✅ POST `/api/v1/applications` → 401 (works, just needs auth)

## Attempted Fixes

### ✅ Fix 1: Made headers optional
- Changed `required: true` to `required: false` for Authorization and X-Supabase-Token in GET
- **Result**: Still 400

### ✅ Fix 2: Moved path parameter to path-item level
- Moved `path` parameter from operation level to path level
- **Result**: Still 400

### ✅ Fix 3: Made GET identical to POST
- Made GET header requirements match POST exactly
- **Result**: Still 400

### ✅ Fix 4: Removed Authorization header parameter
- Removed Authorization from OpenAPI spec (can conflict with gateway auth)
- **Result**: Still 400

## Current OpenAPI Spec

```yaml
paths:
  /{path=**}:
    parameters:
      - name: path
        in: path
        required: true
        type: string
    get:
      operationId: orchestrationGet
      parameters:
        - in: header
          name: X-Supabase-Token
          type: string
          required: true
          description: Supabase JWT token (preserved by API Gateway, used by proxy service)
      x-google-backend:
        address: ${proxy_service_url}
        path_translation: APPEND_PATH_TO_ADDRESS
        protocol: h2
        jwt_audience: ${proxy_service_url}
      responses:
        '200':
          description: Success
    post:
      operationId: orchestrationPost
      parameters:
        - in: header
          name: X-Supabase-Token
          type: string
          required: true
          description: Supabase JWT token (preserved by API Gateway, used by proxy service)
      x-google-backend:
        address: ${proxy_service_url}
        path_translation: APPEND_PATH_TO_ADDRESS
        protocol: h2
        jwt_audience: ${proxy_service_url}
      responses:
        '200':
          description: Success
```

## Observations

1. **POST works, GET doesn't** - This is method-specific
2. **All GET paths fail** - Not just company search, but all GET requests
3. **Path parameter is correctly placed** - At path level, not operation level
4. **Backend address is correct** - Points to proxy service, not gateway
5. **No self-call loop** - Verified backend address

## Possible Root Causes

1. **API Gateway bug/limitation** with catch-all patterns for GET requests
2. **Query parameter handling** - GET requests with query params may not work with `/{path=**}`
3. **Protocol h2 issue** - `protocol: h2` might not be supported for GET requests
4. **Path translation issue** - `APPEND_PATH_TO_ADDRESS` might not work correctly for GET

## Next Steps to Try

1. **Remove `protocol: h2`** from GET operation (try default HTTP/1.1)
2. **Try `CONSTANT_ADDRESS`** instead of `APPEND_PATH_TO_ADDRESS`
3. **Use explicit paths** instead of catch-all (e.g., `/api/v1/companies/search`, `/api/v1/applications`)
4. **Check API Gateway logs** for specific validation errors
5. **Report as API Gateway bug** if all else fails

## Workaround

Until fixed, consider:
- Using POST requests where possible
- Calling proxy service directly (bypassing API Gateway)
- Using explicit paths for known GET endpoints
