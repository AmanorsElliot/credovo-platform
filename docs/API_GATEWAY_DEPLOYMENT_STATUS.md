# API Gateway Deployment Status

## ✅ Successfully Deployed

- **API Gateway URL**: `https://proxy-gateway-ayd13s2s.ew.gateway.dev`
- **State**: ACTIVE
- **Service Account**: `orchestration-service@credovo-eu-apps-nonprod.iam.gserviceaccount.com`
- **IAM Permission**: Granted ✅

## ⚠️ Current Issue: 403 Forbidden

The API Gateway returns 403 when accessing endpoints. This is likely because:
- The API config still points to the old `proxy-service` URL
- The config update failed (update command doesn't support `--openapi-spec`)

## 🔧 Fix Required

The API config needs to be deleted and recreated with the correct orchestration service URL.

### Option 1: Run Script Again (Recommended)

The script now automatically handles deletion and recreation:

```powershell
cd scripts
.\deploy-api-gateway.ps1
```

### Option 2: Manual Fix

```powershell
# Delete existing config
gcloud api-gateway api-configs delete proxy-api-config `
    --api=proxy-api `
    --project=credovo-eu-apps-nonprod `
    --quiet

# Wait a moment
Start-Sleep -Seconds 3

# Recreate (script will do this automatically)
cd scripts
.\deploy-api-gateway.ps1
```

## After Fix

Once the config is updated to point to orchestration-service:

1. **Test health endpoint**:
   ```powershell
   $gatewayUrl = "https://proxy-gateway-ayd13s2s.ew.gateway.dev"
   Invoke-RestMethod -Uri "$gatewayUrl/health" -Method GET
   ```

2. **Update Edge Function** to use the API Gateway URL

3. **Test full flow** from Edge Function → API Gateway → Orchestration Service

## Next Steps

1. ✅ Run the deployment script again to update the API config
2. ✅ Test the health endpoint
3. ✅ Update Edge Function configuration
4. ✅ Test end-to-end flow
