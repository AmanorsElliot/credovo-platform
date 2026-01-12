# API Gateway 403 Forbidden Fix

## Issue

API Gateway is deployed and active, but returns 403 Forbidden when accessing endpoints.

## Likely Cause

The API config still points to the old `proxy-service` URL instead of `orchestration-service`. The update command failed because `gcloud api-gateway api-configs update` doesn't support the `--openapi-spec` flag.

## Solution

Delete and recreate the API config with the correct orchestration service URL:

```powershell
# Delete existing config
gcloud api-gateway api-configs delete proxy-api-config `
    --api=proxy-api `
    --project=credovo-eu-apps-nonprod `
    --quiet

# Wait a moment
Start-Sleep -Seconds 2

# Recreate with correct URL (pointing to orchestration-service)
cd scripts
.\deploy-api-gateway.ps1
```

Or run the script again - it now handles deletion and recreation automatically.

## Verify Configuration

After recreating, verify the config points to orchestration-service:

```powershell
gcloud api-gateway api-configs describe proxy-api-config `
    --api=proxy-api `
    --project=credovo-eu-apps-nonprod `
    --format="yaml" | Select-String "orchestration"
```

## Test After Fix

```powershell
$gatewayUrl = "https://proxy-gateway-ayd13s2s.ew.gateway.dev"
Invoke-RestMethod -Uri "$gatewayUrl/health" -Method GET
```

Should return: `{"status":"healthy","service":"orchestration-service","ready":true}`
