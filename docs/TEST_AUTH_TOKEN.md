# Getting Authentication Tokens for Testing

This guide explains how to get an authentication token for running the test suite.

## Token Types

The Credovo platform supports two authentication methods:

1. **Supabase JWT** (Recommended) - Tokens issued by Supabase
2. **Backend JWT** (Legacy) - Tokens issued by the backend via token exchange

## Quick Start: Get Backend Token

Use the helper script to get a backend-issued token:

```powershell
.\scripts\get-test-token.ps1
```

This will:
- Generate a test token via the `/api/v1/auth/token` endpoint
- Display the token
- Copy it to your clipboard
- Show you how to use it in tests

### Custom Options

```powershell
# Custom user ID and email
.\scripts\get-test-token.ps1 -UserId "my-test-user" -Email "test@example.com"

# Use a specific orchestration URL
.\scripts\get-test-token.ps1 -OrchestrationUrl "https://your-service.run.app"
```

## Using Supabase JWT Token

If you're using Supabase authentication (recommended):

### Option 1: From Frontend (Lovable)

1. **Log in to your frontend** (Lovable app)
2. **Open browser DevTools** (F12)
3. **Go to Application/Storage tab**
4. **Find the Supabase session**:
   - Look for `sb-<project-id>-auth-token` in localStorage
   - Or check Network tab for API requests with `Authorization: Bearer` header
5. **Copy the token** (the part after `Bearer `)

### Option 2: Generate via Supabase Client

```typescript
// In your frontend code or browser console
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  'YOUR_SUPABASE_URL',
  'YOUR_SUPABASE_ANON_KEY'
);

const { data: { session } } = await supabase.auth.signInWithPassword({
  email: 'test@example.com',
  password: 'password'
});

console.log('Token:', session?.access_token);
```

### Use in Tests

```powershell
.\scripts\get-test-token.ps1 -UseSupabase -SupabaseToken "your-supabase-token"
```

Or directly in test script:
```powershell
.\scripts\test-comprehensive.ps1 -AuthToken "your-supabase-token"
```

## Backend Token Exchange

The backend provides a token exchange endpoint for testing:

### Endpoint

```
POST /api/v1/auth/token
```

### Request

```json
{
  "userId": "test-user-123",
  "email": "test@example.com",  // Optional
  "name": "Test User"           // Optional
}
```

### Response

```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expiresIn": 604800,  // 7 days in seconds
  "user": {
    "id": "test-user-123",
    "email": "test@example.com",
    "name": "Test User"
  }
}
```

### Example with curl

```bash
curl -X POST https://orchestration-service-saz24fo3sa-ew.a.run.app/api/v1/auth/token \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "test-user-123",
    "email": "test@example.com"
  }'
```

## Which Token to Use?

### Use Supabase JWT if:
- ✅ You have Supabase configured
- ✅ You want to test with real user authentication
- ✅ You're testing the full authentication flow
- ✅ You want to match production behavior

### Use Backend Token if:
- ✅ You're doing quick testing
- ✅ Supabase is not configured
- ✅ You need a simple token for API testing
- ✅ You're testing backend functionality only

## Token Validation

The backend automatically detects which token type you're using:

- **Supabase JWT**: Validated using JWKS (ES256/RS256) or JWT secret (HS256 fallback)
- **Backend JWT**: Validated using `SERVICE_JWT_SECRET` (HS256)

## Testing Without Token

Some endpoints don't require authentication:

- `GET /health` - Health check
- `GET /api/v1/webhooks/health` - Webhook health check
- `POST /api/v1/auth/token` - Token exchange (no auth needed)

For other endpoints, authentication is required.

## Troubleshooting

### "Invalid or expired token"

- **Check token expiration**: Backend tokens expire after 7 days
- **Verify token format**: Should start with `eyJ` (base64 encoded JWT header)
- **Check token type**: Ensure you're using the correct token type for your setup

### "Missing authorization header"

- Ensure you're including: `Authorization: Bearer <token>`
- Check that the header is spelled correctly

### "JWT validation failed"

- **Supabase token**: Verify `SUPABASE_URL` or `SUPABASE_JWKS_URI` is configured
- **Backend token**: Verify `SERVICE_JWT_SECRET` is configured
- **Token format**: Ensure token is not corrupted or truncated

## Security Notes

⚠️ **Important**: 
- Test tokens are for development/testing only
- Never commit tokens to version control
- Tokens should be kept secure
- Use environment variables or secure storage for tokens in production

## Quick Reference

```powershell
# Get backend token
.\scripts\get-test-token.ps1

# Run tests with token
.\scripts\test-comprehensive.ps1 -AuthToken "your-token"

# Get token and run tests in one go
$token = (.\scripts\get-test-token.ps1 | Select-String -Pattern "Token:" | ForEach-Object { $_.Line.Split(':')[1].Trim() })
.\scripts\test-comprehensive.ps1 -AuthToken $token
```

