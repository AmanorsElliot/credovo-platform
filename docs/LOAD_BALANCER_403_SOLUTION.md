# Load Balancer 403 Forbidden - Solution

## Problem

The Load Balancer is returning 403 Forbidden when accessing the proxy service, even though:
- ✅ IAM permissions are correctly set
- ✅ Service accounts have `roles/run.invoker`
- ✅ Load Balancer is deployed and forwarding requests

## Root Cause

For **serverless NEGs with Cloud Run**, the Load Balancer needs to authenticate, but there's a limitation:

**Serverless NEGs don't support explicit service account configuration in the backend service.** The Load Balancer should automatically use a service account to authenticate, but this might not be working correctly.

## The Real Issue

When using a Load Balancer with a serverless NEG pointing to Cloud Run:
1. The Load Balancer forwards requests to Cloud Run
2. Cloud Run checks IAM authentication **before** the request reaches the application
3. Even though service accounts have `roles/run.invoker`, the Load Balancer might not be including an identity token
4. Cloud Run rejects the request with 403

## Solution: Request Organization Policy Exemption

Since the Load Balancer approach has authentication limitations, the **simplest solution** is to:

1. **Request an exemption** from `iam.allowedPolicyMemberDomains` for the proxy service
2. **Add `allUsers`** to the proxy service IAM policy
3. **Use the proxy service directly** from the Edge Function (no Load Balancer needed)

This is actually simpler and more straightforward than the Load Balancer approach.

## Alternative: Use API Gateway

If you want to keep using a Load Balancer-like solution:
- **API Gateway** might handle authentication differently
- **Cloud Endpoints** could be another option

## Current Status

- ✅ Load Balancer infrastructure deployed
- ✅ IAM permissions configured
- ❌ Authentication not working (403 errors)
- ⏭️ Need to either fix Load Balancer auth OR request policy exemption

## Recommended Action

**Request organization policy exemption** to allow `allUsers` on the proxy service. This is the cleanest solution and avoids the Load Balancer authentication complexity.
