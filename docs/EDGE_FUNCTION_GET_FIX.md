# Edge Function GET Request Fix for API Gateway

## Problem

API Gateway rejects GET requests with 400 error, even with explicit routes. The Edge Function needs to call the gateway with a proper GET request that passes API Gateway validation.

## Solution: Proper GET Request Format

When calling API Gateway with GET requests, ensure:
1. **No Content-Type header** (GET requests shouldn't have Content-Type)
2. **No request body** (GET requests don't have bodies)
3. **Query parameters in URL** (not in body)
4. **Only X-Supabase-Token header** (Authorization is added by API Gateway)

## Edge Function Code Update

Update your Supabase Edge Function (e.g., `supabase/functions/applications/index.ts` or `supabase/functions/search/index.ts`) to call the gateway correctly:

```typescript
// Extract Supabase JWT token
const authHeader = req.headers.get("Authorization");
if (!authHeader || !authHeader.startsWith("Bearer ")) {
  return new Response(
    JSON.stringify({ error: "Missing or invalid authorization header" }),
    { status: 401, headers: { "Content-Type": "application/json" } }
  );
}

const supabaseToken = authHeader.substring(7);
const apiGatewayUrl = Deno.env.get("API_GATEWAY_URL") || 
  "https://proxy-gateway-ayd13s2s.ew.gateway.dev";

// For GET requests, use proper GET format
if (req.method === "GET") {
  // Extract query parameters from request URL
  const url = new URL(req.url);
  const queryString = url.search; // Includes the "?" if present
  
  // Build the full URL with query parameters
  const targetUrl = `${apiGatewayUrl}${url.pathname}${queryString}`;
  
  console.log(`[Edge Function] Calling API Gateway GET: ${targetUrl}`);
  console.log(`[Edge Function] Query params: ${queryString}`);
  
  try {
    const backendResponse = await fetch(targetUrl, {
      method: "GET",
      headers: {
        // DO NOT include Content-Type for GET requests
        // DO NOT include Authorization (API Gateway adds it)
        "X-Supabase-Token": supabaseToken, // Only this header
      },
      // DO NOT include body for GET requests
    });
    
    console.log(`[Edge Function] API Gateway response status: ${backendResponse.status}`);
    
    if (!backendResponse.ok) {
      const errorText = await backendResponse.text();
      console.error(`[Edge Function] API Gateway error: ${errorText}`);
      
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
    console.log(`[Edge Function] Success: ${JSON.stringify(data).substring(0, 100)}`);
    
    return new Response(
      JSON.stringify(data),
      {
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
      }
    );
  } catch (error: any) {
    console.error(`[Edge Function] Fetch error: ${error.message}`);
    return new Response(
      JSON.stringify({ 
        error: "Internal Server Error",
        message: error.message 
      }),
      { 
        status: 500,
        headers: { "Content-Type": "application/json" }
      }
    );
  }
} else {
  // POST, PUT, DELETE - include Content-Type and body
  const body = await req.json();
  
  const backendResponse = await fetch(`${apiGatewayUrl}${url.pathname}`, {
    method: req.method,
    headers: {
      "X-Supabase-Token": supabaseToken,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
  
  // ... handle response
}
```

## Key Points

1. **For GET requests**:
   - ✅ Method: `GET`
   - ✅ Headers: Only `X-Supabase-Token` (no `Content-Type`, no `Authorization`)
   - ✅ Query params: In URL (`?query=test&limit=10`)
   - ✅ Body: None

2. **For POST/PUT/DELETE requests**:
   - ✅ Method: `POST`/`PUT`/`DELETE`
   - ✅ Headers: `X-Supabase-Token` and `Content-Type: application/json`
   - ✅ Body: JSON payload

3. **Logging**: Add console.log statements to debug:
   - Request URL being called
   - Query parameters
   - Response status
   - Error messages

## Testing

After updating the Edge Function:

```bash
# Test company search
curl -X GET "https://your-project.supabase.co/functions/v1/applications?path=/api/v1/companies/search&query=test&limit=10" \
  -H "Authorization: Bearer YOUR_SUPABASE_JWT"
```

Check Edge Function logs in Supabase dashboard to see the debug output.

## If Still Failing

If GET requests still fail after this fix:
1. Check Edge Function logs for the exact request being sent
2. Verify the API Gateway URL is correct
3. Check if API Gateway logs show validation errors
4. Consider the alternative: call proxy service directly (bypassing API Gateway)
