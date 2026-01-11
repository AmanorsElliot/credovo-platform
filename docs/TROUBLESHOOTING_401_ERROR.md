# Troubleshooting 401 Unauthorized Error

## Overview

This guide covers the 401 error that occurs when the Supabase Edge Function calls the orchestration service.

## Root Cause

The 401 error is caused by **Cloud Run IAM blocking requests** before they reach the application code. Cloud Run requires Google Identity Tokens, but the Edge Function sends Supabase JWT tokens.

## Solution: Proxy Service (Regulatory Compliant)

Due to regulatory requirements preventing `allUsers` access, we use a **proxy service** pattern:

1. **Edge Function** → Calls proxy service (public access)
2. **Proxy Service** → Uses service account to call orchestration service
3. **Orchestration Service** → Validates Supabase JWT from `X-User-Token` header

See `docs/PROXY_SERVICE_SETUP.md` for implementation details.

## Architecture

```
Supabase Edge Function
    ↓ (public call with Supabase JWT)
Proxy Service (Cloud Run, public access)
    ↓ (service account auth, forwards Supabase JWT in X-User-Token)
Orchestration Service (Cloud Run, authenticated)
    ↓ (validates Supabase JWT)
Application Logic
```

## Quick Diagnosis

**Run the diagnostic script first:**
```powershell
.\scripts\diagnose-401-error.ps1
```

This will check:
- ✅ Proxy service deployment and accessibility
- ✅ Orchestration service configuration
- ✅ Service account permissions
- ✅ Recent authentication errors
- ✅ End-to-end flow (if token provided)

See `docs/DIAGNOSE_401_ERROR.md` for detailed troubleshooting steps.

## Quick Fix Steps

1. **Deploy Proxy Service** - See `docs/PROXY_SERVICE_SETUP.md`
2. **Grant Service Account Access** - Proxy service account needs `roles/run.invoker` on orchestration service
3. **Update Edge Function** - Point to proxy service URL instead of orchestration service
4. **Test** - Verify end-to-end flow works

## Verification

After deploying the proxy service:

```powershell
# Test proxy health
Invoke-RestMethod -Uri "https://proxy-service-XXXXX-ew.a.run.app/health"

# Test with Supabase JWT
$supabaseToken = "your-supabase-jwt-token"
Invoke-RestMethod -Uri "https://proxy-service-XXXXX-ew.a.run.app/api/v1/applications" `
  -Method POST `
  -Headers @{
    "Authorization" = "Bearer $supabaseToken"
    "Content-Type" = "application/json"
  } `
  -Body (@{type="business_mortgage";data=@{}} | ConvertTo-Json)
```

## Related Documentation

- `docs/PROXY_SERVICE_SETUP.md` - Complete proxy service setup guide
- `docs/REGULATORY_COMPLIANT_SOLUTION.md` - Solution overview
- `docs/APPLICATION_CREATION_ENDPOINT.md` - Application creation endpoint details
- `docs/SUPABASE_EDGE_FUNCTION_AUTH.md` - Edge Function authentication guide
