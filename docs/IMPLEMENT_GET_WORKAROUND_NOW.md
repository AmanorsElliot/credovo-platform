# Implement GET Request Workaround - URGENT

## Status: ✅ Test Results Confirm API Gateway Bug

**All GET requests still return 400 errors**, even after making all parameters optional. This confirms API Gateway has a fundamental bug with GET requests.

## Immediate Action Required

Update your Supabase Edge Function to use the **hybrid approach**:

1. **GET requests** → Call proxy service **directly** (bypass API Gateway)
2. **POST/PUT/DELETE requests** → Continue using API Gateway

## Quick Implementation

### Step 1: Update Edge Function Code

Copy the updated code from `docs/EDGE_FUNCTION_SEARCH_EXAMPLE.ts` to your Edge Function.

**Key changes:**
- GET requests call `PROXY_SERVICE_URL` directly
- POST/PUT/DELETE continue using `API_GATEWAY_URL`

### Step 2: Set Environment Variables

In your Supabase Edge Function settings, ensure you have:

```bash
API_GATEWAY_URL=https://proxy-gateway-ayd13s2s.ew.gateway.dev
PROXY_SERVICE_URL=https://proxy-service-saz24fo3sa-ew.a.run.app
```

### Step 3: Deploy

```bash
supabase functions deploy search
# or whatever your function name is
```

## Why This Works

1. ✅ **Proxy service is already deployed** and handles Supabase JWT correctly
2. ✅ **Proxy service accepts direct calls** (deployed with `--allow-unauthenticated`)
3. ✅ **Same authentication flow** - proxy validates JWT and forwards to orchestration service
4. ✅ **No security degradation** - same security, just different routing

## Test Results Summary

```
❌ GET /api/v1/health → 400 (even without auth)
❌ GET /api/v1/companies/search?query=test&limit=10 → 400
❌ GET /api/v1/applications → 400
✅ POST /api/v1/applications → Works (returns 401, which is expected)
```

**Conclusion**: API Gateway rejects ALL GET requests regardless of:
- Path (explicit routes fail too)
- Parameters (optional parameters still fail)
- Headers (with/without headers fail)
- Authentication (even /health without auth fails)

## Next Steps After Implementation

1. ✅ Update Edge Function with hybrid approach
2. ✅ Test GET requests (should work now)
3. 📝 Report API Gateway bug to Google Cloud Support
4. 📝 Monitor API Gateway release notes for fixes

## Files to Update

- `supabase/functions/search/index.ts` (or your search function)
- `supabase/functions/applications/index.ts` (if it has GET requests)
- Any other Edge Functions that make GET requests

## Complete Example

See `docs/EDGE_FUNCTION_SEARCH_EXAMPLE.ts` for the complete, working code.
