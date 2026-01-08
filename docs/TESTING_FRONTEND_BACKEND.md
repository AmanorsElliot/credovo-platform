# Testing Frontend-Backend Communication

This guide helps you verify that your Lovable frontend can communicate with the Cloud Run backend.

## Prerequisites

- Backend deployed to Cloud Run
- Frontend configured with `REACT_APP_API_URL` environment variable
- Supabase authentication set up in Lovable

## Quick Test Script

Run the PowerShell test script:

```powershell
.\scripts\test-backend-connection.ps1
```

Or specify a custom backend URL:

```powershell
.\scripts\test-backend-connection.ps1 -BackendUrl "https://your-backend-url.run.app"
```

## Manual Testing Steps

### 1. Test Health Endpoint (No Auth Required)

**From PowerShell:**
```powershell
$backendUrl = "https://orchestration-service-saz24fo3sa-ew.a.run.app"
Invoke-WebRequest -Uri "$backendUrl/health" -UseBasicParsing
```

**Expected Response:**
```json
{
  "status": "healthy",
  "service": "orchestration-service"
}
```

**From Frontend (Lovable):**
```typescript
const response = await fetch(`${process.env.REACT_APP_API_URL}/health`);
const data = await response.json();
console.log(data); // { status: 'healthy', service: 'orchestration-service' }
```

### 2. Test CORS (Cross-Origin Requests)

**From Browser Console (in Lovable app):**
```javascript
fetch('https://orchestration-service-saz24fo3sa-ew.a.run.app/health', {
  method: 'GET',
  headers: {
    'Content-Type': 'application/json'
  }
})
.then(res => res.json())
.then(data => console.log('Success:', data))
.catch(err => console.error('Error:', err));
```

**Expected:** Should return `{ status: 'healthy', service: 'orchestration-service' }`

If you see CORS errors, check:
- Backend CORS configuration in `shared/auth/jwt-validator.ts`
- `LOVABLE_FRONTEND_URL` or `FRONTEND_URL` environment variable in Cloud Run

### 3. Test Authentication Flow

#### Option A: Using Supabase JWT (Recommended)

**From Frontend (Lovable):**
```typescript
import { supabase } from "@/integrations/supabase/client";

// 1. Get Supabase session
const { data: { session } } = await supabase.auth.getSession();

if (!session) {
  console.error('Not authenticated');
  return;
}

// 2. Extract JWT token
const jwtToken = session.access_token;

// 3. Make authenticated request
const response = await fetch(`${process.env.REACT_APP_API_URL}/api/v1/applications`, {
  method: 'GET',
  headers: {
    'Authorization': `Bearer ${jwtToken}`,
    'Content-Type': 'application/json'
  }
});

if (response.ok) {
  const data = await response.json();
  console.log('Success:', data);
} else {
  const error = await response.json();
  console.error('Error:', error);
}
```

#### Option B: Using Token Exchange (If not using Supabase)

**Step 1: Exchange user info for backend token**
```typescript
// Get user info from Lovable
const user = await lovable.getUser(); // Adjust based on Lovable API

// Exchange for backend token
const tokenResponse = await fetch(`${process.env.REACT_APP_API_URL}/api/v1/auth/token`, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    userId: user.id,
    email: user.email,
    name: user.name
  })
});

const { token } = await tokenResponse.json();
```

**Step 2: Use token for authenticated requests**
```typescript
const response = await fetch(`${process.env.REACT_APP_API_URL}/api/v1/applications`, {
  method: 'GET',
  headers: {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  }
});
```

### 4. Test Protected Endpoint

**From Frontend:**
```typescript
// This endpoint requires authentication
const response = await fetch(`${process.env.REACT_APP_API_URL}/api/v1/applications`, {
  method: 'GET',
  headers: {
    'Authorization': `Bearer ${jwtToken}`, // Supabase JWT or backend token
    'Content-Type': 'application/json'
  }
});

if (response.status === 401) {
  console.error('Unauthorized - check token');
} else if (response.ok) {
  const data = await response.json();
  console.log('Applications:', data);
}
```

### 5. Test Auth Verify Endpoint

**From Frontend:**
```typescript
const response = await fetch(`${process.env.REACT_APP_API_URL}/api/v1/auth/verify`, {
  method: 'GET',
  headers: {
    'Authorization': `Bearer ${jwtToken}`,
    'Content-Type': 'application/json'
  }
});

const result = await response.json();
if (result.valid) {
  console.log('Token is valid:', result.user);
} else {
  console.error('Token invalid:', result.error);
}
```

## Available Endpoints

### Public Endpoints (No Auth Required)

- `GET /health` - Health check
- `POST /api/v1/auth/token` - Token exchange (if using backend JWT)
- `GET /api/v1/auth/verify` - Verify token

### Protected Endpoints (Auth Required)

- `GET /api/v1/applications` - List applications
- `POST /api/v1/applications/:id/kyc/initiate` - Initiate KYC
- `GET /api/v1/applications/:id/kyc/status` - Get KYC status

## Troubleshooting

### CORS Errors

**Error:** `Access to fetch at '...' from origin '...' has been blocked by CORS policy`

**Solution:**
1. Check backend CORS configuration in `shared/auth/jwt-validator.ts`
2. Verify `LOVABLE_FRONTEND_URL` or `FRONTEND_URL` is set in Cloud Run
3. Ensure your frontend URL is in the `allowedOrigins` array

### 401 Unauthorized

**Error:** `401 Unauthorized` when making authenticated requests

**Possible Causes:**
1. **Missing or invalid token:**
   - Verify you're sending the token: `Authorization: Bearer <token>`
   - Check token is not expired
   - For Supabase: Ensure `session.access_token` is used (not `session.refresh_token`)

2. **Wrong authentication method:**
   - Backend uses Supabase JWT if `SUPABASE_URL` is set
   - Otherwise uses backend-issued JWT
   - Check which method your backend is configured for

3. **Token format:**
   - Ensure token starts with `Bearer ` (with space)
   - Format: `Authorization: Bearer <token>`

**Solution:**
```typescript
// Debug: Log token (first 20 chars only for security)
console.log('Token:', jwtToken.substring(0, 20) + '...');

// Test token verification endpoint
const verifyResponse = await fetch(`${process.env.REACT_APP_API_URL}/api/v1/auth/verify`, {
  headers: { 'Authorization': `Bearer ${jwtToken}` }
});
const verifyResult = await verifyResponse.json();
console.log('Token verification:', verifyResult);
```

### 403 Forbidden

**Error:** `403 Forbidden`

**Possible Causes:**
1. Service account doesn't have proper permissions
2. Organization policy blocking access
3. Service not properly deployed

**Solution:**
- Check Cloud Run service logs
- Verify service account has `roles/run.invoker` permission
- Check organization policies

### Connection Refused / Network Error

**Error:** `Failed to fetch` or `Network request failed`

**Possible Causes:**
1. Backend URL is incorrect
2. Backend service is down
3. Network/firewall blocking request

**Solution:**
1. Verify backend URL:
   ```powershell
   gcloud run services describe orchestration-service --region=europe-west1 --project=credovo-eu-apps-nonprod --format="value(status.url)"
   ```

2. Test from browser:
   ```javascript
   // Open browser console and run:
   fetch('https://orchestration-service-saz24fo3sa-ew.a.run.app/health')
     .then(r => r.json())
     .then(console.log)
   ```

3. Check service status:
   ```powershell
   gcloud run services list --region=europe-west1 --project=credovo-eu-apps-nonprod
   ```

## Testing Checklist

- [ ] Health endpoint returns `200 OK`
- [ ] CORS preflight (OPTIONS) returns `200 OK` with CORS headers
- [ ] Unauthenticated requests to protected endpoints return `401`
- [ ] Token exchange (if using) returns valid token
- [ ] Token verification returns `{ valid: true, user: {...} }`
- [ ] Authenticated requests to protected endpoints return `200 OK`
- [ ] Frontend can make requests from browser console
- [ ] Frontend can make requests from React components

## Next Steps

Once basic connectivity is verified:

1. **Test full KYC flow:**
   - Create application
   - Initiate KYC
   - Check KYC status
   - Handle webhooks

2. **Test error handling:**
   - Invalid tokens
   - Expired tokens
   - Network errors
   - Backend errors

3. **Monitor in production:**
   - Set up Cloud Monitoring alerts
   - Check Cloud Run logs
   - Monitor error rates

## Example Frontend Integration

```typescript
// utils/api.ts
const API_URL = process.env.REACT_APP_API_URL;

export async function apiRequest(
  endpoint: string,
  options: RequestInit = {}
): Promise<Response> {
  // Get Supabase session
  const { data: { session } } = await supabase.auth.getSession();
  
  if (!session) {
    throw new Error('Not authenticated');
  }

  const response = await fetch(`${API_URL}${endpoint}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${session.access_token}`,
      ...options.headers,
    },
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.message || 'API request failed');
  }

  return response;
}

// Usage
const applications = await apiRequest('/api/v1/applications').then(r => r.json());
```

