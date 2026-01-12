# Load Balancer Authentication Fix

## Problem

The Load Balancer is returning 403 Forbidden when accessing the proxy service. The Load Balancer has the correct IAM permissions, but requests are still being rejected.

## Root Cause

For serverless NEGs with Cloud Run, the Load Balancer needs to authenticate using a service account. However, the authentication might not be working correctly because:

1. The Load Balancer might be using the Compute Engine default service account
2. The service account needs proper permissions to get identity tokens
3. The backend service might need explicit service account configuration

## Current Status

✅ **IAM Permissions:**
- `load-balancer-proxy@credovo-eu-apps-nonprod.iam.gserviceaccount.com` has `roles/run.invoker`
- `858440156644-compute@developer.gserviceaccount.com` has `roles/run.invoker`

❌ **Still Getting 403:**
- Load Balancer requests are being rejected
- Cloud Run logs show "request was not authenticated"

## Solution Options

### Option 1: Use Cloud Run Direct URL (Bypass Load Balancer)

Since the Load Balancer authentication is complex, we could:
1. Request an exemption for `iam.allowedPolicyMemberDomains` to allow `allUsers` on the proxy service
2. Use the proxy service URL directly from the Edge Function

### Option 2: Configure Backend Service with Service Account

For serverless NEGs, we might need to configure the backend service to explicitly use a service account. However, Terraform's `google_compute_backend_service` resource doesn't support this for serverless backends.

### Option 3: Use Cloud Endpoints / API Gateway

API Gateway might handle authentication differently and could be a better solution.

### Option 4: Make Proxy Service Public (Request Exemption)

The simplest solution is to request an organization policy exemption to allow `allUsers` on the proxy service, then use it directly without the Load Balancer.

## Recommended Next Steps

1. **Contact GCP Support** to request exemption for `iam.allowedPolicyMemberDomains` for the proxy service
2. **OR** investigate if there's a way to configure the Load Balancer backend service to use a specific service account for authentication
3. **OR** consider using API Gateway instead of Load Balancer

## Testing

To test if the Load Balancer is working:
```powershell
# This should work if authentication is configured correctly
Invoke-WebRequest -Uri "http://136.110.129.171/health" -Method GET
```

Currently returns: `403 Forbidden`
