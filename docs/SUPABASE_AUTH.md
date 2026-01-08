# Supabase Authentication Integration

## Overview

Since you're using **Supabase** through Lovable for authentication, Supabase provides JWT tokens that we can validate directly on our backend. This is simpler than the token exchange pattern.

## Architecture

```
┌─────────┐         ┌──────────┐         ┌─────────────────┐
│ Frontend│         │ Supabase │         │ Backend API     │
└────┬────┘         └────┬─────┘         └────────┬────────┘
     │                   │                        │
     │ 1. User Login      │                        │
     ├──────────────────>│                        │
     │                   │                        │
     │ 2. Supabase JWT   │                        │
     │<──────────────────┤                        │
     │                   │                        │
     │ 3. API Request    │                        │
     │    with JWT       │                        │
     ├───────────────────────────────────────────>│
     │    Authorization: Bearer <supabase-token> │
     │                   │                        │
     │                   │ 4. Validate JWT        │
     │                   │    (using SUPABASE_   │
     │                   │     JWT_SECRET)        │
     │                   │                        │
     │ 5. API Response   │                        │
     │<───────────────────────────────────────────┤
```

## Setup

### Step 1: Get Supabase Project URL

1. Go to your Supabase project dashboard
2. Navigate to **Settings** → **API**
3. Find your **Project URL** (e.g., `https://jywjbinndnanxscxqdes.supabase.co`)
4. Copy this URL

### Step 2: Configure Backend Secrets

Add the Supabase project URL to GCP Secret Manager:

```powershell
# Add Supabase URL to Secret Manager
$supabaseUrl = "https://jywjbinndnanxscxqdes.supabase.co"  # Replace with your URL
$supabaseUrl | gcloud secrets versions add supabase-url --data-file=-
```

Or manually:
```powershell
echo -n "https://jywjbinndnanxscxqdes.supabase.co" | gcloud secrets versions add supabase-url --data-file=-
```

**Note**: The backend will automatically construct the JWKS endpoint as: `{SUPABASE_URL}/auth/v1/.well-known/jwks.json`

For example: `https://jywjbinndnanxscxqdes.supabase.co/auth/v1/.well-known/jwks.json`

### Optional: Add Supabase JWT Secret (for fallback validation)

If you want to support both JWKS (RS256) and JWT secret (HS256) validation:

1. Go to Supabase Dashboard → **Settings** → **API**
2. Find the **JWT Secret** (also called "JWT Signing Secret")
3. Add it to Secret Manager:

```powershell
$supabaseJwtSecret = Read-Host "Enter your Supabase JWT Secret"
$supabaseJwtSecret | gcloud secrets versions add supabase-jwt-secret --data-file=-
```

**Note**: JWKS validation (RS256) is preferred and doesn't require the JWT secret. The JWT secret is only needed as a fallback.

### Step 3: Update Terraform (if needed)

The secret should be accessible to Cloud Run services. It's already configured in `infrastructure/terraform/cloud-run.tf`.

### Step 4: Deploy Updated Service

The orchestration service automatically detects Supabase if `SUPABASE_URL` is set. No code changes needed!

## Frontend Implementation

### Get Supabase JWT Token

After user authenticates with Supabase, get the JWT token:

```typescript
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.REACT_APP_SUPABASE_URL!,
  process.env.REACT_APP_SUPABASE_ANON_KEY!
);

// After user signs in
const { data: { session } } = await supabase.auth.signInWithPassword({
  email: 'user@example.com',
  password: 'password'
});

// Get the JWT token
const token = session?.access_token;

// Store token
localStorage.setItem('supabaseToken', token);
```

### Use Token for API Requests

```typescript
const token = localStorage.getItem('supabaseToken');

const response = await fetch(`${process.env.REACT_APP_API_URL}/api/v1/applications/123/kyc/initiate`, {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    type: 'individual',
    data: { /* ... */ }
  })
});
```

### Handle Token Refresh

Supabase tokens expire. Handle refresh automatically:

```typescript
// Supabase automatically refreshes tokens, but you can listen for changes
supabase.auth.onAuthStateChange((event, session) => {
  if (session) {
    localStorage.setItem('supabaseToken', session.access_token);
  }
});
```

## Environment Variables

### Backend (GCP Secret Manager)
- `SUPABASE_URL`: Supabase project URL (e.g., `https://xxx.supabase.co`)
- `SUPABASE_AUDIENCE`: JWT audience (default: `authenticated`)

### Frontend (Lovable Environment Variables)
- `REACT_APP_API_URL`: Backend API URL
- `REACT_APP_SUPABASE_URL`: Your Supabase project URL
- `REACT_APP_SUPABASE_ANON_KEY`: Supabase anon/public key

## Token Validation

The backend validates Supabase JWTs using:
- **Algorithm**: RS256 (RSA with SHA-256)
- **JWKS Endpoint**: `{SUPABASE_URL}/auth/v1/.well-known/jwks.json`
- **Audience**: `authenticated` (default, configurable via `SUPABASE_AUDIENCE`)
- **Payload**: Contains `sub` (user ID), `email`, `role`, and other Supabase claims

## Advantages of Using Supabase JWTs

✅ **Simpler**: No token exchange needed  
✅ **Secure**: Tokens are signed by Supabase  
✅ **Standard**: Uses standard JWT validation  
✅ **Automatic Refresh**: Supabase handles token refresh  
✅ **User Management**: Supabase manages user accounts  

## Migration from Token Exchange

If you were using the token exchange pattern (`/api/v1/auth/token`), you can:

1. **Keep both**: Support both Supabase JWTs and token exchange
2. **Switch completely**: Use only Supabase JWTs (recommended)
3. **Hybrid**: Use Supabase for new users, token exchange for legacy

## Troubleshooting

### Token Validation Fails

- Verify `SUPABASE_URL` is set correctly (should be your full Supabase project URL)
- Check JWKS endpoint is accessible: `{SUPABASE_URL}/auth/v1/.well-known/jwks.json`
- Verify token hasn't expired (Supabase tokens typically last 1 hour)
- Ensure token is sent in `Authorization: Bearer <token>` header
- Check token audience matches (should be `authenticated`)

### Secret Not Found

```powershell
# Verify secret exists
gcloud secrets list | grep supabase

# Check secret value
gcloud secrets versions access latest --secret=supabase-url
```

### JWKS Endpoint Issues

Test the JWKS endpoint directly:
```powershell
# Replace with your Supabase URL
curl https://your-project.supabase.co/auth/v1/.well-known/jwks.json
```

Should return JSON with public keys.

### CORS Issues

Ensure your Supabase frontend URL is in the allowed origins:

```typescript
// In shared/auth/jwt-validator.ts
const allowedOrigins = [
  process.env.SUPABASE_FRONTEND_URL,  // Add your Supabase frontend URL
  process.env.LOVABLE_FRONTEND_URL,
  'http://localhost:3000'
];
```

## Next Steps

1. ✅ Get Supabase project URL from dashboard
2. ✅ Add URL to GCP Secret Manager as `supabase-url`
3. ✅ Deploy infrastructure (Terraform will create the secret placeholder)
4. ✅ Update secret with actual Supabase URL
5. ✅ Deploy updated service
6. ✅ Test authentication flow

