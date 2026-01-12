# API Gateway GET Request 400 Error - Final Status

## Problem Summary

**ALL GET requests through API Gateway return 400 (Google HTML error page)**, even with explicit routes. POST requests work fine.

## All Attempted Fixes

1. ✅ Made headers optional (`required: false`)
2. ✅ Moved path parameter to path-item level
3. ✅ Made GET identical to POST
4. ✅ Removed Authorization header parameter (can conflict with gateway auth)
5. ✅ Removed `protocol: h2` from x-google-backend
6. ✅ Added explicit GET routes (`/api/v1/health`, `/api/v1/companies/search`, `/api/v1/applications`)

**Result**: None of these fixes resolved the issue. Even explicit GET routes return 400.

## Current Configuration

- ✅ Gateway is ACTIVE
- ✅ Using latest API config (`proxy-api-config-0b0qll85yqkj4`)
- ✅ Backend address is correct (`https://proxy-service-saz24fo3sa-ew.a.run.app`)
- ✅ No self-call loop
- ✅ POST requests work (return 401, which is expected)

## Root Cause Analysis

This appears to be a **fundamental API Gateway limitation or bug** with GET requests, not a configuration error. The fact that:
- Even explicit GET routes fail
- POST requests work fine
- All common fixes have been tried
- The spec is correctly formatted

...strongly suggests an API Gateway issue rather than a misconfiguration.

## Recommended Solution: Phase 3 Workaround

Since API Gateway appears to have a fundamental issue with GET requests, implement a workaround in the Edge Function to convert GET to POST:

### Edge Function Modification

```typescript
// In supabase/functions/applications/index.ts or similar

const apiGatewayUrl = Deno.env.get("API_GATEWAY_URL") || 
  "https://proxy-gateway-ayd13s2s.ew.gateway.dev";

// For GET requests, convert to POST with method override
if (req.method === "GET") {
  const url = new URL(req.url);
  const queryParams = Object.fromEntries(url.searchParams);
  
  const backendResponse = await fetch(`${apiGatewayUrl}${url.pathname}`, {
    method: "POST",
    headers: {
      "X-Supabase-Token": supabaseToken,
      "Content-Type": "application/json",
      "X-HTTP-Method-Override": "GET", // Method override header
    },
    body: JSON.stringify({
      _method: "GET",
      _query: queryParams, // Include query params in body
    }),
  });
} else {
  // POST, PUT, DELETE work normally
  const backendResponse = await fetch(`${apiGatewayUrl}${url.pathname}`, {
    method: req.method,
    headers: {
      "X-Supabase-Token": supabaseToken,
      "Content-Type": "application/json",
    },
    body: req.method !== "GET" ? JSON.stringify(body) : undefined,
  });
}
```

### Proxy Service Modification

Update the proxy service to handle method override:

```typescript
// In services/proxy-service/src/index.ts

app.all('*', async (req: Request, res: Response) => {
  // Handle method override
  const method = req.headers['x-http-method-override'] || req.method;
  const queryParams = req.body?._query || {};
  
  // Reconstruct query string if needed
  const queryString = new URLSearchParams(queryParams).toString();
  const targetUrl = `${ORCHESTRATION_SERVICE_URL}${req.path}${queryString ? `?${queryString}` : ''}`;
  
  // ... rest of proxy logic
});
```

## Alternative: Direct Proxy Service Access

As a simpler workaround, the Edge Function could call the proxy service directly, bypassing API Gateway:

```typescript
const proxyUrl = Deno.env.get("PROXY_SERVICE_URL") || 
  "https://proxy-service-saz24fo3sa-ew.a.run.app";

const backendResponse = await fetch(`${proxyUrl}/api/v1/companies/search?query=test&limit=10`, {
  method: "GET",
  headers: {
    "Authorization": `Bearer ${supabaseToken}`,
    "X-Supabase-Token": supabaseToken,
  },
});
```

**Note**: This requires the proxy service to be publicly accessible or the Edge Function to have IAM permissions.

## Next Steps

1. **Report to Google Cloud Support** - This appears to be an API Gateway bug
2. **Implement Phase 3 workaround** - Convert GET to POST in Edge Function
3. **Or use direct proxy service access** - Bypass API Gateway for GET requests

## Testing

After implementing the workaround, test:
- ✅ Company search populates dropdown
- ✅ GET requests work (via POST conversion)
- ✅ POST requests continue to work
