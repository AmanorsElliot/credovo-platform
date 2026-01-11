# Proxy Service Setup Guide

## Overview

The proxy service acts as a bridge between Supabase Edge Functions and the orchestration service, allowing requests while maintaining regulatory compliance.

## Architecture

```
Supabase Edge Function
    ↓ (public call with Supabase JWT)
Proxy Service (Cloud Run, public access)
    ↓ (service account auth, forwards Supabase JWT)
Orchestration Service (Cloud Run, authenticated)
    ↓ (validates Supabase JWT)
Application Logic
```

## Deployment Steps

### Step 1: Build and Deploy Proxy Service

```powershell
# Build the Docker image
cd services/proxy-service
docker build -t gcr.io/credovo-eu-apps-nonprod/proxy-service:latest .

# Push to Artifact Registry
docker push gcr.io/credovo-eu-apps-nonprod/proxy-service:latest

# Deploy to Cloud Run
gcloud run deploy proxy-service `
  --image gcr.io/credovo-eu-apps-nonprod/proxy-service:latest `
  --region europe-west1 `
  --platform managed `
  --allow-unauthenticated `
  --service-account proxy-service@credovo-eu-apps-nonprod.iam.gserviceaccount.com `
  --set-env-vars ORCHESTRATION_SERVICE_URL=https://orchestration-service-saz24fo3sa-ew.a.run.app `
  --project credovo-eu-apps-nonprod
```

### Step 2: Grant Proxy Service Access to Orchestration Service

```powershell
# Grant proxy service account access to orchestration service
gcloud run services add-iam-policy-binding orchestration-service `
  --region=europe-west1 `
  --member="serviceAccount:proxy-service@credovo-eu-apps-nonprod.iam.gserviceaccount.com" `
  --role=roles/run.invoker `
  --project=credovo-eu-apps-nonprod
```

### Step 3: Create Service Account for Proxy

```powershell
# Create service account
gcloud iam service-accounts create proxy-service `
  --display-name="Proxy Service Account" `
  --description="Service account for proxy service" `
  --project=credovo-eu-apps-nonprod
```

### Step 4: Update Edge Function

Update the Edge Function to call the proxy service instead of orchestration service directly:

```typescript
// In Edge Function
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

## Security

### ✅ Compliant with Regulations

- **No `allUsers` on orchestration service** - Only service account access
- **Public proxy** - Acceptable because it only forwards authenticated requests
- **Service account auth** - Proxy authenticates to orchestration service
- **JWT validation** - Application still validates Supabase JWT

### 🔒 Security Layers

1. **Edge Function** - Validates user session
2. **Proxy Service** - Public but only forwards authenticated requests
3. **Orchestration Service** - Validates Supabase JWT from `X-User-Token` header
4. **Application Logic** - Uses validated user ID for authorization

## Testing

### Test Proxy Service

```powershell
# Test health endpoint
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

## Terraform Integration

Add to `infrastructure/terraform/cloud-run.tf`:

```hcl
resource "google_cloud_run_service" "proxy_service" {
  name     = "proxy-service"
  location = var.region

  template {
    spec {
      service_account_name = google_service_account.services["proxy-service"].email
      
      containers {
        image = "gcr.io/${var.project_id}/proxy-service:latest"

        env {
          name  = "ORCHESTRATION_SERVICE_URL"
          value = google_cloud_run_service.orchestration_service.status[0].url
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

# Allow public access to proxy service
resource "google_cloud_run_service_iam_member" "proxy_public_access" {
  service  = google_cloud_run_service.proxy_service.name
  location = google_cloud_run_service.proxy_service.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Grant proxy service access to orchestration service
resource "google_cloud_run_service_iam_member" "proxy_invoke_orchestration" {
  service  = google_cloud_run_service.orchestration_service.name
  location = google_cloud_run_service.orchestration_service.location
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.services["proxy-service"].email}"
}
```

## Benefits

✅ **Regulatory Compliant** - No `allUsers` on orchestration service  
✅ **Secure** - Service account authentication between services  
✅ **Maintains Auth** - Supabase JWT still validated  
✅ **Simple** - Minimal code changes  
✅ **Scalable** - Can add rate limiting, caching, etc. to proxy  

## Next Steps

1. Deploy proxy service
2. Grant service account access
3. Update Edge Function to use proxy
4. Test end-to-end flow
