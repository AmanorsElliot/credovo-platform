# Proxy Service Organization Policy Exemption Request

## Current Issue

The proxy service is deployed but returns **403 Forbidden** because:
- Organization policy `constraints/gcp.resourceLocations` blocks `allUsers` access
- The proxy service needs public access for Supabase Edge Functions to call it
- Edge Functions run in Supabase (not GCP), so they can't use GCP service accounts

## Why Proxy Service Needs Public Access

The architecture requires:
```
Supabase Edge Function (external, Supabase JWT only)
  ↓
Proxy Service (MUST be public - Edge Function can't use GCP auth)
  ↓
Orchestration Service (authenticated, validates Supabase JWT)
```

**Edge Functions cannot:**
- Use GCP service accounts
- Get Google Identity Tokens
- Authenticate to Cloud Run using IAM

**Edge Functions can only:**
- Make HTTP requests with Supabase JWT tokens
- Call publicly accessible endpoints

## Requesting an Exemption

### Option 1: Request Organization Policy Exemption

Request an exemption for the proxy service to allow `allUsers` access:

**Justification:**
- The proxy service only forwards authenticated requests (requires Supabase JWT)
- It doesn't expose sensitive data - it's a pass-through proxy
- Application layer enforces authentication (Supabase JWT validation)
- Required for Supabase Edge Function integration
- No alternative architecture that maintains security boundaries

**Request Format:**

```json
{
  "name": "projects/858440156644/policies/constraints.gcp.resourceLocations/exemptions/proxy-service-public-access",
  "spec": {
    "exemptions": [
      {
        "name": "proxy-service-public-access",
        "resource": "projects/858440156644/locations/europe-west1/services/proxy-service",
        "reason": "Required for Supabase Edge Function integration. Service only forwards authenticated requests with Supabase JWT tokens. Application layer enforces authentication.",
        "constraint": "constraints/gcp.resourceLocations"
      }
    ]
  }
}
```

### Option 2: Use Terraform to Apply (May Still Require Exemption)

Add the proxy service to Terraform and try to apply the IAM binding:

```hcl
# Add to infrastructure/terraform/cloud-run.tf

resource "google_cloud_run_service" "proxy_service" {
  name     = "proxy-service"
  location = var.region

  template {
    spec {
      service_account_name = google_service_account.services["proxy-service"].email
      
      containers {
        image = "europe-west1-docker.pkg.dev/${var.project_id}/credovo-services/proxy-service:latest"

        resources {
          limits = {
            cpu    = "1"
            memory = "512Mi"
          }
        }

        env {
          name  = "ORCHESTRATION_SERVICE_URL"
          value = google_cloud_run_service.orchestration_service.status[0].url
        }

        ports {
          container_port = 8080
        }
      }

      timeout_seconds = 300
    }

    metadata {
      annotations = {
        "autoscaling.knative.dev/minScale" = "0"
        "autoscaling.knative.dev/maxScale" = "10"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  lifecycle {
    ignore_changes = [template[0].spec[0].containers[0].image]
  }
}

# Attempt to make proxy service publicly accessible
# This will fail if organization policy blocks it
resource "google_cloud_run_service_iam_member" "proxy_public_access" {
  service  = google_cloud_run_service.proxy_service.name
  location = google_cloud_run_service.proxy_service.location
  role     = "roles/run.invoker"
  member   = "allUsers"
  
  # This may fail due to organization policy
  # If it fails, request an exemption (see Option 1)
}

# Grant proxy service access to orchestration service
resource "google_cloud_run_service_iam_member" "proxy_invoke_orchestration" {
  service  = google_cloud_run_service.orchestration_service.name
  location = google_cloud_run_service.orchestration_service.location
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.services["proxy-service"].email}"
}
```

### Option 3: Temporary Workaround - Make Orchestration Service Public

If exemption cannot be obtained immediately, you can temporarily make the orchestration service public:

**⚠️ WARNING: This bypasses the proxy service architecture and may violate regulatory requirements.**

```powershell
# This will also fail if org policy blocks it
gcloud run services add-iam-policy-binding orchestration-service `
  --region=europe-west1 `
  --member="allUsers" `
  --role="roles/run.invoker" `
  --project=credovo-eu-apps-nonprod `
  --condition=None
```

Then update Edge Function to call orchestration service directly (not recommended for production).

## Security Justification

The proxy service is safe to make public because:

1. **No Sensitive Data**: It only forwards requests - doesn't store or process data
2. **Authentication Required**: All requests must include Supabase JWT token
3. **Application Layer Security**: Orchestration service validates JWT before processing
4. **Rate Limiting**: Can be added to proxy service to prevent abuse
5. **Logging**: All requests are logged for audit purposes

## Verification After Exemption

Once exemption is granted or policy is updated:

```powershell
# Test proxy service is publicly accessible
$proxyUrl = "https://proxy-service-saz24fo3sa-ew.a.run.app"
Invoke-RestMethod -Uri "$proxyUrl/health"

# Should return: {"status":"healthy","service":"proxy-service"}
```

## Next Steps

1. **Request exemption** from organization policy administrator
2. **Or** update organization policy to allow `allUsers` for specific services
3. **Apply IAM binding** once exemption is granted:
   ```powershell
   gcloud run services add-iam-policy-binding proxy-service `
     --region=europe-west1 `
     --member="allUsers" `
     --role="roles/run.invoker" `
     --project=credovo-eu-apps-nonprod `
     --condition=None
   ```
4. **Test** Edge Function → Proxy Service → Orchestration Service flow

## Contact

For exemption requests, contact your GCP organization policy administrator with:
- Service: `proxy-service` in project `credovo-eu-apps-nonprod`
- Location: `europe-west1`
- Justification: Required for Supabase Edge Function integration
- Security: Application-layer authentication enforced
