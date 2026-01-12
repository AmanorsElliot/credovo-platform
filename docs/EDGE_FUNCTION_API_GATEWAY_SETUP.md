# Edge Function Setup for API Gateway

## Problem

When using API Gateway, the `Authorization` header is overwritten with API Gateway's identity token. The Supabase JWT needs to be preserved and forwarded to the orchestration service.

## Solution

Send the Supabase JWT in **both** the `Authorization` header (for API Gateway authentication) **and** the `X-Supabase-Token` header (which API Gateway will forward to the proxy service).

## Update Edge Function

In your Supabase Edge Function (`supabase/functions/applications/index.ts`), update the API call:

```typescript
// Extract the Supabase JWT token
const authHeader = req.headers.get("Authorization");
if (!authHeader || !authHeader.startsWith("Bearer ")) {
  return new Response(
    JSON.stringify({ error: "Missing or invalid authorization header" }),
    { status: 401, headers: { "Content-Type": "application/json" } }
  );
}

const supabaseToken = authHeader.substring(7);

// API Gateway URL
const apiGatewayUrl = Deno.env.get("API_GATEWAY_URL") || 
  "https://proxy-gateway-ayd13s2s.ew.gateway.dev";

// Call API Gateway
const backendResponse = await fetch(`${apiGatewayUrl}/api/v1/applications`, {
  method: "POST",
  headers: {
    "Authorization": `Bearer ${supabaseToken}`, // For API Gateway (will be overwritten)
    "X-Supabase-Token": supabaseToken, // Preserved by API Gateway, used by proxy service
    "Content-Type": "application/json",
  },
  body: JSON.stringify(body),
});
```

## How It Works

1. **Edge Function** → Sends Supabase JWT in both `Authorization` and `X-Supabase-Token` headers
2. **API Gateway** → Receives request, overwrites `Authorization` with its identity token, forwards `X-Supabase-Token` unchanged
3. **Proxy Service** → Extracts Supabase JWT from `X-Supabase-Token` header, forwards as `X-User-Token` to orchestration service
4. **Orchestration Service** → Validates Supabase JWT from `X-User-Token` header

## Testing

After updating the Edge Function, test the flow:

```bash
# Get a Supabase JWT token (from your frontend or Supabase dashboard)
SUPABASE_TOKEN="your-supabase-jwt-token"

# Test API Gateway directly
curl -X POST https://proxy-gateway-ayd13s2s.ew.gateway.dev/api/v1/applications \
  -H "Authorization: Bearer $SUPABASE_TOKEN" \
  -H "X-Supabase-Token: $SUPABASE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"type": "individual", "data": {}}'
```

## Environment Variables

Set in Supabase dashboard or via CLI:

```bash
supabase secrets set API_GATEWAY_URL=https://proxy-gateway-ayd13s2s.ew.gateway.dev
```

## Troubleshooting

If you get "Invalid or expired token" errors:

1. **Check proxy service logs**: Verify it's receiving the `X-Supabase-Token` header
   ```bash
   gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=proxy-service" --limit=10 --project=credovo-eu-apps-nonprod
   ```

2. **Check orchestration service logs**: Verify it's receiving the `X-User-Token` header
   ```bash
   gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=orchestration-service" --limit=10 --project=credovo-eu-apps-nonprod
   ```

3. **Verify Edge Function is sending both headers**: Check the Edge Function code to ensure both `Authorization` and `X-Supabase-Token` are set.

4. **Check Supabase JWT validity**: Ensure the token is valid and not expired.
