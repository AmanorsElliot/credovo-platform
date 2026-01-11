# Diagnosing 401 Unauthorized Error

## Quick Diagnosis Checklist

### Step 1: Verify Edge Function is Using Proxy Service

The Edge Function **must** call the proxy service, not the orchestration service directly.

**Check Edge Function Code:**
- Should use `PROXY_SERVICE_URL` environment variable
- Should NOT use `BACKEND_API_URL` or orchestration service URL directly
- Should forward Supabase JWT in `Authorization: Bearer <token>` header

**Expected Edge Function Code:**
```typescript
const proxyUrl = Deno.env.get("PROXY_SERVICE_URL") || 
  "https://proxy-service-XXXXX-ew.a.run.app";

const backendResponse = await fetch(`${proxyUrl}/api/v1/applications`, {
  method: "POST",
  headers: {
    "Authorization": `Bearer ${token}`, // Supabase JWT
    "Content-Type": "application/json",
  },
  body: JSON.stringify(body),
});
```

### Step 2: Verify Proxy Service is Deployed

```powershell
# Check if proxy service exists
gcloud run services describe proxy-service `
  --region=europe-west1 `
  --project=credovo-eu-apps-nonprod

# Get proxy service URL
$proxyUrl = (gcloud run services describe proxy-service `
  --region=europe-west1 `
  --project=credovo-eu-apps-nonprod `
  --format="value(status.url)")

Write-Host "Proxy Service URL: $proxyUrl"

# Test proxy health
Invoke-RestMethod -Uri "$proxyUrl/health"
```

### Step 3: Verify Orchestration Service Configuration

```powershell
# Check if SUPABASE_URL is configured
gcloud run services describe orchestration-service `
  --region=europe-west1 `
  --project=credovo-eu-apps-nonprod `
  --format="value(spec.template.spec.containers[0].env)" | 
  Select-String "SUPABASE"

# Check orchestration service logs for auth middleware selection
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=orchestration-service AND textPayload=~'Auth middleware selected'" `
  --limit 5 `
  --format json `
  --project=credovo-eu-apps-nonprod
```

**Expected log message:** `[STARTUP] Auth middleware selected: Supabase`

### Step 4: Verify Service Account Permissions

```powershell
# Check if proxy service account has access to orchestration service
gcloud run services get-iam-policy orchestration-service `
  --region=europe-west1 `
  --project=credovo-eu-apps-nonprod

# Should see: serviceAccount:proxy-service@credovo-eu-apps-nonprod.iam.gserviceaccount.com with role: roles/run.invoker
```

### Step 5: Test End-to-End Flow

```powershell
# 1. Get a valid Supabase JWT token (from your frontend or Supabase dashboard)
$supabaseToken = "your-supabase-jwt-token-here"

# 2. Get proxy service URL
$proxyUrl = (gcloud run services describe proxy-service `
  --region=europe-west1 `
  --project=credovo-eu-apps-nonprod `
  --format="value(status.url)")

# 3. Test proxy service with Supabase JWT
try {
  $response = Invoke-RestMethod -Uri "$proxyUrl/api/v1/applications" `
    -Method POST `
    -Headers @{
      "Authorization" = "Bearer $supabaseToken"
      "Content-Type" = "application/json"
    } `
    -Body (@{
      type = "business_mortgage"
      data = @{}
    } | ConvertTo-Json)
  
  Write-Host "✅ Success! Application created:" -ForegroundColor Green
  $response | ConvertTo-Json -Depth 10
} catch {
  Write-Host "❌ Error:" -ForegroundColor Red
  $_.Exception.Message
  if ($_.ErrorDetails.Message) {
    Write-Host $_.ErrorDetails.Message
  }
}
```

### Step 6: Check Orchestration Service Logs

```powershell
# Check recent orchestration service logs for authentication errors
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=orchestration-service AND (textPayload=~'JWT' OR textPayload=~'Unauthorized' OR textPayload=~'Missing token')" `
  --limit 20 `
  --format json `
  --project=credovo-eu-apps-nonprod | 
  ConvertFrom-Json | 
  ForEach-Object { 
    Write-Host "Timestamp: $($_.timestamp)"
    Write-Host "Message: $($_.textPayload)"
    Write-Host "---"
  }
```

## Common Issues and Solutions

### Issue 1: Edge Function Calling Orchestration Service Directly

**Symptom:** Error shows orchestration service URL in logs

**Solution:** Update Edge Function to use `PROXY_SERVICE_URL` instead of `BACKEND_API_URL`

### Issue 2: Proxy Service Not Deployed

**Symptom:** Cannot reach proxy service URL

**Solution:** Deploy proxy service (see `docs/PROXY_SERVICE_SETUP.md`)

### Issue 3: SUPABASE_URL Not Configured

**Symptom:** Logs show "Auth middleware selected: Backend" instead of "Supabase"

**Solution:**
```powershell
# Set Supabase URL
$supabaseUrl = "https://your-project.supabase.co"
echo -n $supabaseUrl | gcloud secrets versions add supabase-url --data-file=- --project=credovo-eu-apps-nonprod

# Update orchestration service to use the secret
gcloud run services update orchestration-service `
  --region=europe-west1 `
  --update-secrets=SUPABASE_URL=supabase-url:latest `
  --project=credovo-eu-apps-nonprod
```

### Issue 4: Service Account Missing Permissions

**Symptom:** Proxy service gets 403 Forbidden when calling orchestration service

**Solution:**
```powershell
# Grant proxy service account access
gcloud run services add-iam-policy-binding orchestration-service `
  --region=europe-west1 `
  --member="serviceAccount:proxy-service@credovo-eu-apps-nonprod.iam.gserviceaccount.com" `
  --role=roles/run.invoker `
  --project=credovo-eu-apps-nonprod
```

### Issue 5: Token Not in X-User-Token Header

**Symptom:** Orchestration service logs show "Missing token" even though proxy received it

**Solution:** Verify proxy service is forwarding token in `X-User-Token` header (should be automatic)

## Debugging Script

Run the comprehensive diagnostic script:

```powershell
.\scripts\diagnose-401-error.ps1
```

This script will:
1. ✅ Check proxy service deployment
2. ✅ Check orchestration service configuration
3. ✅ Check service account permissions
4. ✅ Test proxy service health
5. ✅ Check recent logs for errors
6. ✅ Provide specific fix recommendations
