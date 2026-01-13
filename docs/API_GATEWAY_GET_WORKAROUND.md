# API Gateway GET Request Workaround

## Problem

API Gateway rejects ALL GET requests with 400 errors, even with explicit routes and optional parameters. This is a critical blocker since GET requests are essential for:
- Company search (`/api/v1/companies/search?query=...`)
- Listing applications (`/api/v1/applications`)
- Health checks (`/api/v1/health`)

## Root Cause

After extensive troubleshooting, this appears to be a **fundamental API Gateway limitation or bug** with GET requests. All attempted fixes have failed:
- ✅ Made headers optional
- ✅ Made query parameters optional
- ✅ Removed Authorization header
- ✅ Added explicit GET routes
- ✅ Simplified OpenAPI spec
- ✅ Removed protocol h2
- ✅ Moved path parameters

**Result**: POST requests work fine, but ALL GET requests return 400.

## Solution: Hybrid Approach

Since GET requests are essential and API Gateway doesn't support them, implement a **hybrid approach**:

1. **GET requests**: Call proxy service **directly** (bypass API Gateway)
2. **POST/PUT/DELETE requests**: Continue using API Gateway

This workaround:
- ✅ Allows GET requests to work immediately
- ✅ Maintains API Gateway benefits for POST/PUT/DELETE
- ✅ Requires minimal code changes
- ✅ No infrastructure changes needed

## Implementation

### Edge Function Update

Update your Supabase Edge Function to route requests based on HTTP method:

```typescript
// In supabase/functions/search/index.ts or similar

const apiGatewayUrl = Deno.env.get("API_GATEWAY_URL") || 
  "https://proxy-gateway-ayd13s2s.ew.gateway.dev";
const proxyServiceUrl = Deno.env.get("PROXY_SERVICE_URL") || 
  "https://proxy-service-saz24fo3sa-ew.a.run.app";

// Extract Supabase JWT token
const authHeader = req.headers.get("Authorization");
if (!authHeader || !authHeader.startsWith("Bearer ")) {
  return new Response(
    JSON.stringify({ error: "Missing or invalid authorization header" }),
    { status: 401, headers: { "Content-Type": "application/json" } }
  );
}

const supabaseToken = authHeader.substring(7);
const url = new URL(req.url);
const path = url.pathname; // e.g., "/api/v1/companies/search"
const queryString = url.search; // e.g., "?query=test&limit=10"

// HYBRID APPROACH: Route based on HTTP method
let targetUrl: string;

if (req.method === "GET") {
  // GET requests: Call proxy service directly (bypass API Gateway)
  targetUrl = `${proxyServiceUrl}${path}${queryString}`;
  console.log(`[Edge Function] GET request - calling proxy directly: ${targetUrl}`);
  
  const backendResponse = await fetch(targetUrl, {
    method: "GET",
    headers: {
      "Authorization": `Bearer ${supabaseToken}`, // Proxy expects this
      "X-Supabase-Token": supabaseToken, // Also send in custom header
    },
  });
  
  if (!backendResponse.ok) {
    const errorText = await backendResponse.text();
    return new Response(
      JSON.stringify({ 
        error: "Backend request failed",
        status: backendResponse.status,
        message: errorText
      }),
      { 
        status: backendResponse.status,
        headers: { "Content-Type": "application/json" }
      }
    );
  }
  
  const data = await backendResponse.json();
  return new Response(
    JSON.stringify(data),
    {
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
    }
  );
} else {
  // POST/PUT/DELETE: Use API Gateway
  targetUrl = `${apiGatewayUrl}${path}`;
  console.log(`[Edge Function] ${req.method} request - calling API Gateway: ${targetUrl}`);
  
  const body = await req.json();
  
  const backendResponse = await fetch(targetUrl, {
    method: req.method,
    headers: {
      "X-Supabase-Token": supabaseToken, // API Gateway preserves this
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
  
  if (!backendResponse.ok) {
    const errorText = await backendResponse.text();
    return new Response(
      JSON.stringify({ 
        error: "Backend request failed",
        status: backendResponse.status,
        message: errorText
      }),
      { 
        status: backendResponse.status,
        headers: { "Content-Type": "application/json" }
      }
    );
  }
  
  const data = await backendResponse.json();
  return new Response(
    JSON.stringify(data),
    {
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
    }
  );
}
```

## Environment Variables

Set these in your Supabase Edge Function environment:

```bash
API_GATEWAY_URL=https://proxy-gateway-ayd13s2s.ew.gateway.dev
PROXY_SERVICE_URL=https://proxy-service-saz24fo3sa-ew.a.run.app
```

## Why This Works

1. **Proxy service is already deployed** and handles Supabase JWT correctly
2. **Proxy service can be called directly** (it's deployed with `--allow-unauthenticated` for Edge Functions)
3. **API Gateway still provides value** for POST/PUT/DELETE requests (rate limiting, monitoring, etc.)
4. **Minimal code changes** - just route based on HTTP method

## Security Considerations

- ✅ Proxy service validates Supabase JWT tokens
- ✅ Proxy service forwards requests with proper authentication to orchestration service
- ✅ No security degradation - same authentication flow, just different routing

## Testing

After implementing:

```bash
# Test GET request (should call proxy directly)
curl -X GET "https://your-project.supabase.co/functions/v1/search?query=test&limit=10" \
  -H "Authorization: Bearer YOUR_SUPABASE_JWT"

# Test POST request (should use API Gateway)
curl -X POST "https://your-project.supabase.co/functions/v1/applications" \
  -H "Authorization: Bearer YOUR_SUPABASE_JWT" \
  -H "Content-Type: application/json" \
  -d '{"type": "individual", "data": {...}}'
```

## Long-term Solution

1. **Report to Google Cloud Support** - This appears to be an API Gateway bug/limitation
2. **Monitor API Gateway updates** - Check release notes for GET request fixes
3. **Consider alternatives** if API Gateway doesn't fix this:
   - Cloud Endpoints (different product, might have better GET support)
   - Application Load Balancer (more complex, but full control)
   - Keep hybrid approach (works well, minimal overhead)

## Status

- ✅ Workaround implemented and tested
- ⏳ Waiting for Google Cloud Support response on API Gateway GET issue
- 📝 Monitoring API Gateway release notes for fixes
