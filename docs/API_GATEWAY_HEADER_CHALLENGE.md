# API Gateway Header Challenge: Authorization Header Conflict

## The Problem

When API Gateway authenticates to Cloud Run:
- API Gateway **adds** `Authorization: Bearer <identity-token>` for Cloud Run IAM
- The original `Authorization: Bearer <Supabase JWT>` from the client is **overwritten**
- HTTP only allows **one** `Authorization` header

## Current Proxy Service Solution

The proxy service solves this by:
1. Extracting Supabase JWT from `Authorization` header
2. Getting Google Identity Token for Cloud Run IAM
3. Putting Supabase JWT in `X-User-Token` header
4. Putting Identity Token in `Authorization` header

This way:
- Cloud Run IAM sees: `Authorization: Bearer <identity-token>` ✅
- Orchestration service sees: `X-User-Token: Bearer <Supabase JWT>` ✅

## Can API Gateway Do This?

### Option 1: Header Transformation (If Supported)

API Gateway would need to:
- Forward original `Authorization` header as `X-User-Token`
- Add its own `Authorization` header for Cloud Run IAM

**Status**: Unknown if API Gateway OpenAPI spec supports this.

### Option 2: Test Current Configuration

The updated configuration points directly to orchestration service. We need to test if:
- API Gateway preserves the original `Authorization` header somehow
- Or if there's a way to configure header forwarding

### Option 3: Keep Proxy Service

If API Gateway can't transform headers:
- Keep the proxy service
- It's a simple service that works
- Adds minimal latency and cost

## Recommendation

**Test the direct connection first**. If it doesn't work due to header conflict:
1. **Keep the proxy service** - It's simple and works
2. **OR** investigate API Gateway policy language for header transformation
3. **OR** check if API Gateway has configuration options for header forwarding

## Next Steps

1. Deploy API Gateway with direct orchestration service configuration
2. Test if it works (might need to check API Gateway logs)
3. If it fails due to missing Supabase JWT, we know we need header transformation
4. Decide: Keep proxy OR find API Gateway header transformation solution
