# Deploy Proxy Service - Quick Guide

## Current Status

✅ **Service account created**: `proxy-service@credovo-eu-apps-nonprod.iam.gserviceaccount.com`  
✅ **IAM permissions granted**: Proxy service account has access to orchestration service  
❌ **Service not deployed**: Cloud Build has permission issues

## Solution Options

### Option 1: Deploy via GitHub Actions (Recommended)

If you have GitHub Actions set up for Cloud Build triggers:

1. **Push the proxy service code** (already done)
2. **Trigger Cloud Build** via GitHub push or manually:
   ```powershell
   # This will trigger the build via GitHub Actions if configured
   git push origin main
   ```

### Option 2: Fix Cloud Build Permissions and Deploy

Grant the necessary service accounts the required permissions:

```powershell
# Get project number (used for Google-managed service accounts)
$projectNumber = (gcloud projects describe credovo-eu-apps-nonprod --format="value(projectNumber)")

# Grant Cloud Build service account permissions (for building images)
gcloud projects add-iam-policy-binding credovo-eu-apps-nonprod `
    --member="serviceAccount:$projectNumber@cloudbuild.gserviceaccount.com" `
    --role="roles/storage.admin" `
    --condition=None `
    --project=credovo-eu-apps-nonprod

gcloud projects add-iam-policy-binding credovo-eu-apps-nonprod `
    --member="serviceAccount:$projectNumber@cloudbuild.gserviceaccount.com" `
    --role="roles/artifactregistry.writer" `
    --condition=None `
    --project=credovo-eu-apps-nonprod

# Grant Compute Engine default service account permissions (for source deployments)
gcloud projects add-iam-policy-binding credovo-eu-apps-nonprod `
    --member="serviceAccount:$projectNumber-compute@developer.gserviceaccount.com" `
    --role="roles/storage.admin" `
    --condition=None `
    --project=credovo-eu-apps-nonprod

gcloud projects add-iam-policy-binding credovo-eu-apps-nonprod `
    --member="serviceAccount:$projectNumber-compute@developer.gserviceaccount.com" `
    --role="roles/artifactregistry.writer" `
    --condition=None `
    --project=credovo-eu-apps-nonprod

# Then deploy
.\scripts\deploy-proxy-service-simple.ps1
```

**Note:** The service accounts with numeric IDs (`$projectNumber@cloudbuild.gserviceaccount.com` and `$projectNumber-compute@developer.gserviceaccount.com`) are Google-managed default service accounts. We use variables to reference them clearly rather than hardcoding numbers.

### Option 3: Manual Docker Build (If Docker Available)

If you have Docker installed locally:

```powershell
# Build image
cd services/proxy-service
docker build -t gcr.io/credovo-eu-apps-nonprod/proxy-service:latest .

# Push to Container Registry
docker push gcr.io/credovo-eu-apps-nonprod/proxy-service:latest

# Deploy to Cloud Run
gcloud run deploy proxy-service `
    --image gcr.io/credovo-eu-apps-nonprod/proxy-service:latest `
    --region europe-west1 `
    --platform managed `
    --allow-unauthenticated `
    --service-account proxy-service@credovo-eu-apps-nonprod.iam.gserviceaccount.com `
    --set-env-vars "ORCHESTRATION_SERVICE_URL=https://orchestration-service-saz24fo3sa-ew.a.run.app" `
    --port 8080 `
    --memory 512Mi `
    --cpu 1 `
    --max-instances 10 `
    --project credovo-eu-apps-nonprod
```

### Option 4: Use Cloud Shell

1. Open [Google Cloud Shell](https://shell.cloud.google.com/)
2. Clone the repository
3. Run the deployment script from there (Cloud Shell has all permissions)

## After Deployment

Once the proxy service is deployed:

1. **Get the service URL:**
   ```powershell
   $proxyUrl = (gcloud run services describe proxy-service `
       --region=europe-west1 `
       --project=credovo-eu-apps-nonprod `
       --format="value(status.url)")
   
   Write-Host "Proxy Service URL: $proxyUrl"
   ```

2. **Test the service:**
   ```powershell
   Invoke-RestMethod -Uri "$proxyUrl/health"
   ```

3. **Update your Edge Function:**
   - Set environment variable: `PROXY_SERVICE_URL=$proxyUrl`
   - Update Edge Function code to use `PROXY_SERVICE_URL` instead of orchestration service URL

## Verification

After deployment, verify everything is working:

```powershell
# Check service is running
gcloud run services describe proxy-service `
    --region=europe-west1 `
    --project=credovo-eu-apps-nonprod

# Test health endpoint
$proxyUrl = (gcloud run services describe proxy-service `
    --region=europe-west1 `
    --project=credovo-eu-apps-nonprod `
    --format="value(status.url)")

Invoke-RestMethod -Uri "$proxyUrl/health"

# Test with a Supabase JWT (replace with your token)
$token = "your-supabase-jwt-token"
Invoke-RestMethod -Uri "$proxyUrl/api/v1/applications" `
    -Method POST `
    -Headers @{
        "Authorization" = "Bearer $token"
        "Content-Type" = "application/json"
    } `
    -Body (@{type="business_mortgage";data=@{}} | ConvertTo-Json)
```

## Current Configuration

- **Service Account**: `proxy-service@credovo-eu-apps-nonprod.iam.gserviceaccount.com` ✅
- **Orchestration Service URL**: `https://orchestration-service-saz24fo3sa-ew.a.run.app`
- **Region**: `europe-west1`
- **IAM Permissions**: ✅ Proxy service account has `roles/run.invoker` on orchestration service

## Next Steps

1. Choose one of the deployment options above
2. Deploy the proxy service
3. Update Edge Function to use proxy service URL
4. Test end-to-end flow
