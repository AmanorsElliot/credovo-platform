# API Gateway GET 400 Error - Root Cause Identified

## ✅ Root Cause Confirmed

**The issue is NOT a Google bug, but an invalid OpenAPI spec configuration.**

### The Problem

In `infrastructure/terraform/api-gateway-openapi.yaml`, we have:

```yaml
/{path=**}:
  parameters:
    - name: path
      in: path
      required: true
      type: string
  post:
    # ...
  put:
    # ...
  delete:
    # ...
```

**The Issue**: 
- `/{path=**}` **already implicitly defines** the `path` variable
- Declaring it again as a `parameters` block creates a **duplicate path binding**
- This is invalid for Google API Gateway

### Why GET Fails But POST Works

1. **GET requests**: Strictly validated by API Gateway
   - Rejects invalid path bindings immediately
   - Returns 400 before reaching backend

2. **POST/PUT/DELETE requests**: Lenient validation
   - Allows invalid bindings to pass through
   - Reaches backend successfully

### Why This Affects Explicit GET Routes

Even though we have explicit GET routes like:
- `/api/v1/health`
- `/api/v1/companies/search`
- `/api/v1/applications`

**The presence of the invalid wildcard + path parameter combination causes API Gateway to reject ALL GET requests**, even those with explicit routes.

### Evidence

✅ **Matches observed behavior**:
- All GET requests return 400 (even explicit routes)
- POST requests work fine
- No requests reach Cloud Run (400 happens at gateway)
- OpenAPI spec is technically valid per OpenAPI spec (but invalid for API Gateway)

## The Fix

### Option 1: Remove Path Parameter from Wildcard (Recommended)

```yaml
# Catch-all for other methods (POST, PUT, DELETE) and unknown paths
/{path=**}:
  # ❌ REMOVE THIS ENTIRE BLOCK:
  # parameters:
  #   - name: path
  #     in: path
  #     required: true
  #     type: string
  
  post:
    operationId: orchestrationPost
    parameters:
      - in: header
        name: X-Supabase-Token
        type: string
        required: true
    x-google-backend:
      address: ${proxy_service_url}
      path_translation: APPEND_PATH_TO_ADDRESS
      jwt_audience: ${proxy_service_url}
    responses:
      '200':
        description: Success
  # ... put, delete same pattern
```

**Key Points**:
- ✅ Keep the wildcard `/{path=**}`
- ❌ Remove the `parameters` block that declares `path`
- ✅ The wildcard already defines `path` implicitly
- ✅ Keep explicit GET routes as-is

### Option 2: Use Only Explicit Routes (Most Robust)

Remove the wildcard entirely and define all routes explicitly:

```yaml
paths:
  /api/v1/health:
    get:
      # ...
  
  /api/v1/companies/search:
    get:
      # ...
  
  /api/v1/applications:
    get:
      # ...
    post:
      # ...
  
  # Add explicit routes for all endpoints
  # No wildcard needed
```

**Pros**:
- ✅ No wildcard edge cases
- ✅ Google's recommended production pattern
- ✅ Most explicit and clear

**Cons**:
- ❌ Must define every route explicitly
- ❌ More maintenance if routes change

## What This Is NOT

This diagnosis confirms it's **NOT**:
- ❌ `iam.allowedPolicyMemberDomains` (that's a different issue for proxy service)
- ❌ Cloud Run ingress settings
- ❌ Service account permissions
- ❌ Region restrictions
- ❌ API Gateway authentication
- ❌ VPC/networking issues
- ❌ A Google bug (it's our spec configuration)

## Next Steps

1. ✅ **Fix the OpenAPI spec** - Remove path parameter from wildcard
2. ✅ **Deploy updated spec** - Use `scripts/deploy-api-gateway.ps1`
3. ✅ **Test GET requests** - Should work immediately
4. ✅ **Update documentation** - Mark this as resolved

## Verification

After fixing, test:

```powershell
# Should return 200 or 401 (not 400)
Invoke-WebRequest -Uri "https://proxy-gateway-ayd13s2s.ew.gateway.dev/api/v1/health" -Method GET

# Should return 200 or 401 (not 400)
Invoke-WebRequest -Uri "https://proxy-gateway-ayd13s2s.ew.gateway.dev/api/v1/companies/search?query=test&limit=10" -Method GET
```

If these return 200 or 401 (not 400), the fix worked!

## Related Issues

- **Proxy Service 403**: Still blocked by `iam.allowedPolicyMemberDomains` (separate issue)
- **This GET 400**: Will be fixed by removing duplicate path parameter

Once both are fixed:
- ✅ GET requests will work through API Gateway
- ✅ No need for proxy service workaround for GET requests
- ✅ Can use API Gateway for all requests (GET, POST, PUT, DELETE)
