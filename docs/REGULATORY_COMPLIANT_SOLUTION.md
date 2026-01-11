# Regulatory-Compliant Solution for 401 Error

## Problem

- Organization policy prevents `allUsers` access (regulatory requirement)
- Edge Function runs in Supabase (not GCP), so can't get GCP identity tokens
- Need to allow Edge Function to call backend while maintaining security boundaries

## Solution: GCP Cloud Function Proxy

Deploy a **Cloud Function** in GCP that acts as a proxy between the Edge Function and the orchestration service.

### Architecture

```
Edge Function (Supabase)
    ↓ (calls with Supabase JWT)
Cloud Function Proxy (GCP, public access)
    ↓ (uses service account, forwards Supabase JWT)
Orchestration Service (GCP, authenticated)
    ↓ (validates Supabase JWT)
Application Logic
```

### How It Works

1. **Edge Function** calls Cloud Function proxy (public access allowed)
2. **Cloud Function** uses its service account to call orchestration service (authenticated)
3. **Cloud Function** forwards Supabase JWT in `X-User-Token` header
4. **Orchestration Service** validates Supabase JWT (already configured)

## Implementation Steps

### Step 1: Create Cloud Function Proxy

Create a new Cloud Function that:
- Accepts requests from Edge Function
- Uses service account to authenticate to Cloud Run
- Forwards Supabase JWT to orchestration service

### Step 2: Grant Cloud Function Access

Grant the Cloud Function's service account `roles/run.invoker` on the orchestration service.

### Step 3: Update Edge Function

Update Edge Function to call the Cloud Function proxy instead of orchestration service directly.

## Benefits

✅ **Regulatory Compliant** - No `allUsers` access needed  
✅ **Secure** - Service account authentication between GCP services  
✅ **Maintains Auth** - Supabase JWT still validated by application  
✅ **Simple** - Minimal changes to existing code  

## Alternative: Cloud Run Proxy Service

Instead of Cloud Function, deploy a lightweight Cloud Run service that:
- Has public access (or specific service account access)
- Proxies requests to orchestration service
- Forwards Supabase JWT

This gives more control and can be managed with Terraform.

## Next Steps

1. **Choose approach** - Cloud Function (simpler) or Cloud Run service (more control)
2. **Implement proxy** - Create the proxy service
3. **Update Edge Function** - Point to proxy instead of orchestration service
4. **Test** - Verify end-to-end flow works

Would you like me to implement the Cloud Function proxy or the Cloud Run proxy service?
