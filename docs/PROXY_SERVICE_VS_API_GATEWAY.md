# Proxy Service vs API Gateway: Best Practice Analysis

## Current Situation

Now that organization policies are fixed and the project can inherit permissions, we need to decide:
1. **Direct public access** to proxy-service (add `allUsers`)
2. **API Gateway** in front of proxy-service
3. **Other options**

## Architecture Options

### Option 1: Direct Public Access (Simplest)

```
Supabase Edge Function
    ↓ (HTTPS - public, with Supabase JWT)
Proxy Service (Cloud Run - public, allUsers)
    ↓ (service account auth, forwards Supabase JWT)
Orchestration Service (Cloud Run - authenticated)
```

**Pros:**
- ✅ Simplest architecture
- ✅ Fewer components (no API Gateway)
- ✅ Lower cost (no API Gateway fees)
- ✅ Lower latency (one less hop)
- ✅ Easier to debug and monitor

**Cons:**
- ⚠️ Requires `allUsers` IAM binding (may still be blocked by `iam.allowedPolicyMemberDomains`)
- ⚠️ Less control over API management features

### Option 2: API Gateway (More Features)

```
Supabase Edge Function
    ↓ (HTTPS - public, with Supabase JWT)
API Gateway (publicly accessible)
    ↓ (authenticates automatically to Cloud Run)
Proxy Service (Cloud Run - authenticated via service account)
    ↓ (service account auth, forwards Supabase JWT)
Orchestration Service (Cloud Run - authenticated)
```

**Pros:**
- ✅ No `allUsers` needed on proxy-service
- ✅ API management features (rate limiting, quotas, analytics)
- ✅ Better for future API versioning
- ✅ More enterprise-ready

**Cons:**
- ❌ More complex architecture
- ❌ Additional cost (~$0.01 per 1,000 requests)
- ❌ Additional latency (extra hop)
- ❌ More components to manage

## Best Practice Recommendation

### For Your Use Case: **Direct Public Access (Option 1)**

**Reasoning:**
1. **Simplicity**: You have a simple proxy use case - just forwarding requests
2. **Cost**: API Gateway adds unnecessary cost for a simple proxy
3. **Performance**: One less hop means lower latency
4. **Maintenance**: Fewer components to manage and monitor

**When to Use API Gateway Instead:**
- You need API management features (rate limiting, quotas, analytics)
- You're building a public API that needs versioning
- You have multiple consumers and need API keys/authentication
- You need request/response transformation
- You're building an enterprise API platform

## Current Status Check

Let's verify if `allUsers` can be added now that policies are fixed:

```powershell
# Test if we can add allUsers
gcloud run services add-iam-policy-binding proxy-service `
    --region=europe-west1 `
    --member="allUsers" `
    --role="roles/run.invoker" `
    --project=credovo-eu-apps-nonprod
```

If this works, **use direct public access**.  
If it's still blocked by `iam.allowedPolicyMemberDomains`, **use API Gateway**.

## Recommendation

**Try direct public access first:**
1. Attempt to add `allUsers` to proxy-service
2. If successful → Use direct access (simpler, cheaper, faster)
3. If blocked → Use API Gateway (workaround for organization policy)

## Implementation

### If Direct Access Works:

```powershell
# Add allUsers
gcloud run services add-iam-policy-binding proxy-service `
    --region=europe-west1 `
    --member="allUsers" `
    --role="roles/run.invoker" `
    --project=credovo-eu-apps-nonprod

# Update Edge Function to use proxy-service directly
# URL: https://proxy-service-saz24fo3sa-ew.a.run.app
```

### If Direct Access Blocked:

```powershell
# Deploy API Gateway (already configured in Terraform)
cd infrastructure/terraform
terraform apply -target=google_api_gateway_api.proxy_api \
    -target=google_api_gateway_api_config.proxy_api_config \
    -target=google_api_gateway_gateway.proxy_gateway

# Grant API Gateway service account permission
$projectNumber = (gcloud projects describe credovo-eu-apps-nonprod --format="value(projectNumber)")
gcloud run services add-iam-policy-binding proxy-service `
    --region=europe-west1 `
    --member="serviceAccount:$projectNumber@cloudservices.gserviceaccount.com" `
    --role="roles/run.invoker" `
    --project=credovo-eu-apps-nonprod

# Update Edge Function to use API Gateway URL
```

## Summary

**Best Practice for Your Case**: Direct public access (if organization policy allows)

**Fallback**: API Gateway (if organization policy blocks `allUsers`)

**Next Step**: Test if `allUsers` can be added to proxy-service.
