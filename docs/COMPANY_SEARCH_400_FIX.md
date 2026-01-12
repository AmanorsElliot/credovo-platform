# Company Search 400 Error Fix

## Problem

When searching for companies, the Edge Function returns a 400 Bad Request error with a Google HTML error page. The error message shows:
```
"<!DOCTYPE html>...Error 400 (Bad Request)...Your client has issued a malformed or illegal request."
```

## Root Cause

The proxy service was constructing the target URL incorrectly when forwarding requests with query parameters. It was using `req.path` (which doesn't include query parameters) and then trying to manually append the query string from `req.url`, which could result in malformed URLs.

## Solution

Updated the proxy service to use `req.originalUrl` or `req.url` directly, which includes both the path and query string:

```typescript
// Before (incorrect):
const targetUrl = `${ORCHESTRATION_SERVICE_URL}${req.path}${req.url.includes('?') ? req.url.substring(req.url.indexOf('?')) : ''}`;

// After (correct):
const pathWithQuery = req.originalUrl || req.url || req.path;
const targetUrl = `${ORCHESTRATION_SERVICE_URL}${pathWithQuery}`;
```

## Testing

After deploying the updated proxy service, test the company search endpoint:

```powershell
$gatewayUrl = "https://proxy-gateway-ayd13s2s.ew.gateway.dev"
$supabaseToken = "<your-supabase-jwt>"

Invoke-RestMethod -Uri "$gatewayUrl/api/v1/companies/search?query=test&limit=10" `
    -Method GET `
    -Headers @{
        "Authorization" = "Bearer $supabaseToken"
        "X-Supabase-Token" = $supabaseToken
    }
```

## Next Steps

1. Deploy the updated proxy service
2. Test company search from the frontend
3. Verify query parameters are correctly forwarded to the orchestration service
