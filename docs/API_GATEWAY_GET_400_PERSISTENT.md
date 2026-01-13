# API Gateway GET 400 Error - Persistent Issue

## Current Status

Even after multiple fixes, GET requests still return 400 errors:
- ❌ GET `/api/v1/health` → 400
- ❌ GET `/api/v1/companies/search?query=test&limit=10` → 400
- ❌ GET `/api/v1/applications` → 400
- ✅ POST `/api/v1/applications` → 401 (works)

## Fixes Applied

1. ✅ Removed wildcard route entirely
2. ✅ Removed duplicate path parameter
3. ✅ Made all parameters optional
4. ✅ Updated host field to actual hostname
5. ✅ Using explicit routes only

**Result**: Still getting 400 errors

## Current Spec Configuration

- ✅ Explicit routes only (no wildcard)
- ✅ Correct host: `proxy-gateway-ayd13s2s.ew.gateway.dev`
- ✅ Optional parameters
- ✅ No duplicate path parameters
- ✅ POST works (proves gateway is functional)

## Possible Remaining Issues

1. **Security Definition Missing**: API Gateway may require a security definition even if not used
2. **Response Schema Issues**: GET response schemas might be causing validation issues
3. **API Gateway Bug**: This may be a genuine bug in API Gateway's GET request handling
4. **Propagation Delay**: Changes may not have fully propagated (unlikely after this long)

## Next Steps

1. **Add security definition** (even if empty/optional)
2. **Simplify response schemas** (remove schema definitions, just use descriptions)
3. **Check API Gateway logs** for specific error messages
4. **Contact Google Cloud Support** if this persists

## Workaround

Until this is resolved, use the hybrid approach:
- GET requests → Call proxy service directly (requires organization policy exemption)
- POST/PUT/DELETE → Use API Gateway

See `docs/API_GATEWAY_GET_WORKAROUND.md` for implementation details.
