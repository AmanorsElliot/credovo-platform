# Edge Function GET Request Fix for API Gateway

## Problem

API Gateway rejects GET requests with 400 error, even with explicit routes. The Edge Function needs to call the gateway with a proper GET request that passes API Gateway validation.

## Solution: Proper GET Request Format

When calling API Gateway with GET requests, ensure:
1. **No Content-Type header** (GET requests shouldn't have Content-Type)
2. **No request body** (GET requests don't have bodies)
3. **Query parameters in URL** (not in body)
4. **Only X-Supabase-Token header** (Authorization is added by API Gateway)

## Complete Edge Function Example

See `docs/EDGE_FUNCTION_SEARCH_EXAMPLE.ts` for a complete, working example of a search Edge Function.

## Key Points for GET Requests

When calling API Gateway with GET requests, the Edge Function must:

1. **Use GET method** (not POST)
2. **Include ONLY X-Supabase-Token header**:
   ```typescript
   headers: {
     "X-Supabase-Token": supabaseToken,
     // NO Content-Type header
     // NO Authorization header
   }
   ```
3. **Put query parameters in URL** (not in body):
   ```typescript
   const url = new URL(req.url);
   const queryString = url.search; // "?query=test&limit=10"
   const targetUrl = `${apiGatewayUrl}/api/v1/companies/search${queryString}`;
   ```
4. **No request body**:
   ```typescript
   fetch(targetUrl, {
     method: "GET",
     headers: { "X-Supabase-Token": supabaseToken },
     // NO body property
   });
   ```

## Common Mistakes to Avoid

❌ **DON'T include Content-Type for GET**:
```typescript
// WRONG
headers: {
  "Content-Type": "application/json", // ❌ GET requests don't have bodies
  "X-Supabase-Token": supabaseToken,
}
```

❌ **DON'T include Authorization header**:
```typescript
// WRONG
headers: {
  "Authorization": `Bearer ${supabaseToken}`, // ❌ API Gateway adds this
  "X-Supabase-Token": supabaseToken,
}
```

❌ **DON'T put query params in body**:
```typescript
// WRONG
fetch(url, {
  method: "GET",
  body: JSON.stringify({ query: "test", limit: 10 }), // ❌ GET has no body
});
```

✅ **DO use query string in URL**:
```typescript
// CORRECT
const url = new URL(req.url);
const targetUrl = `${apiGatewayUrl}/api/v1/companies/search${url.search}`;
fetch(targetUrl, {
  method: "GET",
  headers: { "X-Supabase-Token": supabaseToken },
});
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
