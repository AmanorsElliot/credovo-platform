# Proxy Service 403 Forbidden Fix

## Problem

When Edge Function calls proxy service directly for GET requests (workaround for API Gateway bug), it gets **403 Forbidden**.

**Root Cause**: The proxy service is not publicly accessible. The organization policy `iam.allowedPolicyMemberDomains` blocks `allUsers` from being added to IAM policies.

## Current Situation

1. ❌ **API Gateway**: Rejects all GET requests with 400 errors
2. ❌ **Proxy Service**: Can't be made public (organization policy blocks `allUsers`)
3. ❌ **Edge Functions**: Can't use GCP authentication (only have Supabase JWT)

## Solutions

### Option 1: Request Organization Policy Exemption (Recommended)

Request an exemption for the proxy service to allow `allUsers` access:

**Justification:**
- Proxy service only forwards authenticated requests (requires Supabase JWT)
- Application layer enforces authentication
- Required for Supabase Edge Function integration
- GET requests are essential functionality

**Request to GCP Support:**
```
Subject: Organization Policy Exemption Request for Proxy Service

We need an exemption for the proxy service (proxy-service) in project 
credovo-eu-apps-nonprod to allow allUsers access (roles/run.invoker).

Justification:
- The proxy service acts as a bridge between Supabase Edge Functions and 
  our orchestration service
- It only forwards requests that include valid Supabase JWT tokens
- Application layer enforces authentication (Supabase JWT validation)
- Required for Supabase Edge Function integration
- Edge Functions cannot use GCP service accounts or Google Identity Tokens
- This is the only way to enable GET requests (API Gateway has a bug 
  that rejects all GET requests with 400 errors)

Service: proxy-service
Project: credovo-eu-apps-nonprod
Region: europe-west1
Policy: iam.allowedPolicyMemberDomains
```

### Option 2: Use API Gateway for All Requests (Temporary Workaround)

Since API Gateway works for POST/PUT/DELETE, we could:
1. Convert GET requests to POST in Edge Function
2. Use `X-HTTP-Method-Override` header
3. Backend treats POST with method override as GET

**Limitation**: This is a workaround and may not work if API Gateway validates the actual HTTP method.

### Option 3: Deploy Proxy Service Behind API Gateway (Alternative)

Instead of calling proxy service directly, route all requests through API Gateway:
1. Update API Gateway OpenAPI spec to point to proxy service
2. Edge Function calls API Gateway for all requests
3. API Gateway forwards to proxy service

**Problem**: API Gateway still rejects GET requests, so this doesn't solve the issue.

### Option 4: Use Cloud Endpoints Instead of API Gateway

Cloud Endpoints might have better GET request support:
1. Deploy Cloud Endpoints configuration
2. Point to proxy service
3. Test if GET requests work

**Consideration**: This requires additional setup and may have the same issues.

## Recommended Action

**Immediate**: Request organization policy exemption for proxy service (Option 1)

**While Waiting**: Document the limitation and consider temporary workarounds

## Current Workaround Status

- ✅ POST/PUT/DELETE: Working via API Gateway
- ❌ GET requests: Blocked (403 from proxy service, 400 from API Gateway)

## Next Steps

1. **Request exemption** from GCP Support for proxy service
2. **Document the issue** for stakeholders
3. **Monitor API Gateway** for GET request bug fix
4. **Consider alternatives** if exemption is denied
