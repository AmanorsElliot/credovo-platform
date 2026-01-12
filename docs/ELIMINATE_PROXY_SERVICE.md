# Eliminate Proxy Service: API Gateway Direct to Orchestration

## Answer: Yes, We Can Eliminate the Proxy!

Looking at the code:

### Orchestration Service JWT Validation

The `validateSupabaseJwt` function checks:
1. **First**: `X-User-Token` header (if present)
2. **Fallback**: `Authorization` header (if X-User-Token not present)

```typescript
// From shared/auth/jwt-validator.ts
if (req.headers['x-user-token']) {
  token = req.headers['x-user-token'] as string;
} else {
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    token = authHeader.substring(7);
  }
}
```

### What API Gateway Can Do

✅ **Authenticate to Cloud Run**: API Gateway automatically adds `Authorization: Bearer <identity-token>` for Cloud Run IAM  
✅ **Forward Headers**: API Gateway can forward the original `Authorization` header  
⚠️ **Issue**: API Gateway's identity token will overwrite the original `Authorization` header

### Solution: Forward Authorization as X-User-Token

Configure API Gateway to:
1. Forward the original `Authorization` header (with Supabase JWT) as `X-User-Token`
2. Let API Gateway add its own `Authorization` header for Cloud Run IAM
3. Orchestration service reads Supabase JWT from `X-User-Token` header

## Updated Architecture

```
Supabase Edge Function
    ↓ (Authorization: Bearer <Supabase JWT>)
API Gateway
    ↓ (Authorization: Bearer <Google Identity Token> for Cloud Run IAM)
    ↓ (X-User-Token: <Supabase JWT> forwarded from original Authorization)
Orchestration Service
    ↓ (reads Supabase JWT from X-User-Token, validates it)
Application Logic
```

## Benefits

- ✅ **Eliminates proxy service** - One less service to maintain
- ✅ **Lower cost** - One less Cloud Run service
- ✅ **Lower latency** - One less hop
- ✅ **Simpler architecture** - Fewer components

## Implementation

### Option 1: Use Header Transformation in API Gateway

API Gateway can transform headers. We need to:
1. Forward `Authorization` header as `X-User-Token`
2. Let API Gateway add its own `Authorization` for Cloud Run IAM

### Option 2: Use Orchestration Service Fallback

Since orchestration service falls back to `Authorization` header:
1. API Gateway forwards `Authorization` header with Supabase JWT
2. API Gateway adds its own `Authorization` for Cloud Run IAM (might overwrite)
3. **Problem**: This won't work if API Gateway overwrites Authorization

### Option 3: Configure API Gateway to Preserve Original Header

Check if API Gateway can preserve the original `Authorization` header while adding its own for Cloud Run IAM.

## Recommendation

**Use header transformation** to forward `Authorization` as `X-User-Token`:
- API Gateway adds `Authorization: Bearer <identity-token>` for Cloud Run IAM
- API Gateway forwards original `Authorization` as `X-User-Token`
- Orchestration service reads from `X-User-Token` (first priority)

This matches what the proxy service does, but API Gateway handles it.

## Next Steps

1. Update API Gateway OpenAPI spec to point directly to orchestration service
2. Configure header transformation to forward Authorization as X-User-Token
3. Grant API Gateway service account permission to invoke orchestration-service
4. Test and remove proxy service if it works
