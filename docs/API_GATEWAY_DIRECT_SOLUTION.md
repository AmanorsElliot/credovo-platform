# API Gateway Direct to Orchestration Service - Solution

## Answer: Yes, We Can Eliminate the Proxy!

### Key Finding

The orchestration service's `validateSupabaseJwt` function:
1. **First checks**: `X-User-Token` header
2. **Falls back to**: `Authorization` header

```typescript
if (req.headers['x-user-token']) {
  token = req.headers['x-user-token'] as string;
} else {
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    token = authHeader.substring(7);
  }
}
```

### The Challenge

API Gateway will:
- ✅ Add `Authorization: Bearer <identity-token>` for Cloud Run IAM
- ⚠️ This might overwrite the original `Authorization` header with Supabase JWT

### Solution Options

#### Option 1: Use Orchestration Service Fallback (Simplest)

If API Gateway preserves the original `Authorization` header before adding its own:
- API Gateway forwards original `Authorization` with Supabase JWT
- API Gateway adds its own `Authorization` for Cloud Run IAM
- **Problem**: Only one Authorization header can exist

**This won't work** - HTTP only allows one Authorization header.

#### Option 2: Header Transformation (If Supported)

Configure API Gateway to:
- Forward original `Authorization` header as `X-User-Token`
- Add its own `Authorization` header for Cloud Run IAM
- Orchestration service reads from `X-User-Token` (first priority)

**This is the correct approach**, but API Gateway OpenAPI spec might not support header transformation.

#### Option 3: Test Current Configuration

The updated OpenAPI spec points directly to orchestration service. Let's test if:
- API Gateway preserves original headers
- Orchestration service can read Supabase JWT from a preserved header

## Updated Configuration

I've updated the API Gateway OpenAPI spec to point directly to orchestration service:
- Backend: `https://orchestration-service-saz24fo3sa-ew.a.run.app`
- Protocol: HTTP/2
- JWT audience: Set to orchestration service URL

## Next Steps

1. **Deploy API Gateway** with the updated configuration
2. **Grant API Gateway permission** to invoke orchestration-service (not proxy-service)
3. **Test** if it works - API Gateway might preserve headers in a way that works
4. **If it doesn't work**, we may need to:
   - Keep the proxy service, OR
   - Use API Gateway's policy language to transform headers (if available)

## Benefits if It Works

- ✅ **Eliminate proxy service** - One less service
- ✅ **Lower cost** - One less Cloud Run service
- ✅ **Lower latency** - One less hop
- ✅ **Simpler architecture**

## Recommendation

**Test the direct connection first**. If API Gateway doesn't preserve the original Authorization header properly, we can:
1. Keep using the proxy service (it works, just adds complexity)
2. Or investigate API Gateway policy language for header transformation

Let's deploy and test!
