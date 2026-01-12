# API Gateway Direct to Orchestration Service

## Question

Can API Gateway communicate directly with the orchestration service, eliminating the need for the proxy service?

## Analysis

### Current Architecture (with Proxy)

```
Supabase Edge Function
    ↓ (Authorization: Bearer <Supabase JWT>)
API Gateway
    ↓ (authenticates via service account, forwards Supabase JWT)
Proxy Service
    ↓ (gets Google Identity Token, forwards Supabase JWT in X-User-Token)
Orchestration Service
```

### Proposed Architecture (without Proxy)

```
Supabase Edge Function
    ↓ (Authorization: Bearer <Supabase JWT>)
API Gateway
    ↓ (authenticates via service account, forwards Supabase JWT)
Orchestration Service
```

## What the Proxy Service Does

1. **Extracts Supabase JWT** from `Authorization` header
2. **Gets Google Identity Token** for Cloud Run IAM authentication
3. **Forwards Supabase JWT** in `X-User-Token` header
4. **Uses Identity Token** in `Authorization` header for Cloud Run IAM

## What API Gateway Can Do

✅ **Authenticate to Cloud Run**: API Gateway automatically authenticates to Cloud Run using its service account  
✅ **Forward Headers**: API Gateway can forward client headers (including `Authorization` header with Supabase JWT)  
✅ **No Proxy Needed**: If orchestration service can accept Supabase JWT directly

## Key Question

**Does the orchestration service need the Supabase JWT in `X-User-Token` header, or can it read it from `Authorization` header?**

If orchestration service can read Supabase JWT from `Authorization` header:
- ✅ **Yes, we can eliminate the proxy**
- API Gateway forwards `Authorization` header
- API Gateway authenticates to Cloud Run automatically
- Orchestration service validates Supabase JWT from `Authorization` header

If orchestration service requires `X-User-Token` header:
- ⚠️ **We might still need proxy** OR
- ⚠️ **We need to configure API Gateway to transform headers**

## Recommendation

**Yes, we can likely eliminate the proxy** if:
1. Orchestration service can read Supabase JWT from `Authorization` header
2. API Gateway is configured to forward the `Authorization` header
3. API Gateway service account has `roles/run.invoker` on orchestration-service

## Next Steps

1. Check orchestration service code to see how it reads Supabase JWT
2. Update API Gateway OpenAPI spec to point directly to orchestration service
3. Grant API Gateway service account permission to invoke orchestration-service
4. Test if it works without proxy

## Benefits of Removing Proxy

- ✅ **Simpler architecture** (one less service)
- ✅ **Lower cost** (one less Cloud Run service)
- ✅ **Lower latency** (one less hop)
- ✅ **Easier to maintain** (fewer components)
