# API Gateway Variable Substitution Fix

## Root Cause Identified

The user identified that the deployed API Gateway config had **unsubstituted variables** (`${proxy_service_url}`) instead of actual backend URLs, causing 400 errors.

### The Issue

1. **Terraform file** (`api-gateway.tf`) uses variable: `orchestration_service_url`
2. **OpenAPI spec** (`api-gateway-openapi.yaml`) uses variable: `${proxy_service_url}`
3. **PowerShell script** (`deploy-api-gateway.ps1`) correctly replaces `${proxy_service_url}`

However, if Terraform was ever used to deploy, it would have left unsubstituted variables in the deployed config.

## Fixes Applied

### 1. Removed Hardcoded Host Field
- API Gateway doesn't enforce the `host` field
- Hardcoded hostname breaks when gateway is recreated
- **Fixed**: Removed `host: proxy-gateway-ayd13s2s.ew.gateway.dev`

### 2. Added Timestamped Config Names
- Static config names (`proxy-api-config`) can cause old configs to persist
- **Fixed**: Use timestamped config names: `proxy-api-config-YYYYMMDDHHmmss`
- Forces new revision on every deployment

### 3. Added Variable Substitution Verification
- Verify `${proxy_service_url}` is replaced before deployment
- **Fixed**: Check temp file for unsubstituted variables before deploying

### 4. Added Backend Address Verification
- Verify deployed config has real URLs, not variables
- **Fixed**: Check deployed config after deployment

## Verification

The PowerShell script correctly replaces variables:
```powershell
$openApiContent = $openApiContent -replace '\$\{proxy_service_url\}', $ProxyServiceUrl
```

Temp file verification shows correct substitution:
```
address: https://proxy-service-saz24fo3sa-ew.a.run.app
```

## Current Status

- ✅ Variable substitution verified in temp file
- ✅ New timestamped config created
- ✅ Gateway using new config
- ⚠️  Still getting 400 errors (may need propagation time or additional fixes)

## Next Steps

1. Wait for config propagation (can take a few minutes)
2. Verify deployed config has real URLs (not variables)
3. Test GET requests again
4. If still failing, check API Gateway logs for specific error

## Testing

```powershell
# Test GET request
curl -i https://proxy-gateway-ayd13s2s.ew.gateway.dev/api/v1/health

# Verify deployed backend address
gcloud api-gateway api-configs describe proxy-api-config-YYYYMMDDHHmmss \
  --api=proxy-api \
  --project=credovo-eu-apps-nonprod \
  --format="yaml" | grep -n "address:"
```

Expected: Real `https://...a.run.app` URL, not `${proxy_service_url}`
