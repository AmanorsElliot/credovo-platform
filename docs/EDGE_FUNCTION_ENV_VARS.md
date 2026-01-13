# Edge Function Environment Variables

## Required Environment Variables

Set these in your Supabase Edge Function settings:

### 1. PROXY_SERVICE_URL (Required)
```
PROXY_SERVICE_URL=https://proxy-service-saz24fo3sa-ew.a.run.app
```
- **Used for**: GET requests (workaround for API Gateway bug)
- **Purpose**: Direct connection to proxy service for GET requests
- **Why**: API Gateway rejects all GET requests with 400 errors

### 2. API_GATEWAY_URL (Required)
```
API_GATEWAY_URL=https://proxy-gateway-ayd13s2s.ew.gateway.dev
```
- **Used for**: POST, PUT, DELETE requests
- **Purpose**: API Gateway provides rate limiting, monitoring, etc. for write operations
- **Why**: API Gateway works fine for POST/PUT/DELETE requests

## How to Set in Supabase

1. Go to your Supabase project dashboard
2. Navigate to **Edge Functions** → **Settings** (or your function's settings)
3. Add environment variables:
   - `PROXY_SERVICE_URL` = `https://proxy-service-saz24fo3sa-ew.a.run.app`
   - `API_GATEWAY_URL` = `https://proxy-gateway-ayd13s2s.ew.gateway.dev`

## Verification

To verify the API Gateway URL is correct:

```powershell
gcloud api-gateway gateways describe proxy-gateway `
  --location=europe-west1 `
  --project=credovo-eu-apps-nonprod `
  --format="value(defaultHostname)"
```

This should return: `proxy-gateway-ayd13s2s.ew.gateway.dev`

## Current URLs

- **Proxy Service**: `https://proxy-service-saz24fo3sa-ew.a.run.app`
- **API Gateway**: `https://proxy-gateway-ayd13s2s.ew.gateway.dev`

## Usage in Code

The Edge Function will automatically use these environment variables:

```typescript
const proxyServiceUrl = Deno.env.get("PROXY_SERVICE_URL") || 
  "https://proxy-service-saz24fo3sa-ew.a.run.app";
const apiGatewayUrl = Deno.env.get("API_GATEWAY_URL") || 
  "https://proxy-gateway-ayd13s2s.ew.gateway.dev";

// GET requests → proxy service
if (req.method === "GET") {
  const targetUrl = `${proxyServiceUrl}${path}${queryString}`;
  // ...
}

// POST/PUT/DELETE → API Gateway
else {
  const targetUrl = `${apiGatewayUrl}${path}`;
  // ...
}
```
