# Connecting Lovable Frontend to Backend

This guide explains how to connect your Lovable frontend to the Credovo backend API.

## Quick Start

### 1. Get Backend API URL

Your orchestration service URL is:
```
https://orchestration-service-saz24fo3sa-ew.a.run.app
```

### 2. Configure Frontend Environment Variables

In your Lovable project settings, add the following environment variables:

```
REACT_APP_API_URL=https://orchestration-service-saz24fo3sa-ew.a.run.app
```

If using Supabase authentication, also add:
```
REACT_APP_SUPABASE_URL=https://your-project.supabase.co
REACT_APP_SUPABASE_ANON_KEY=your-anon-key
```

### 3. Configure CORS (Backend)

The backend needs to allow your frontend origin. Use the provided script:

```powershell
# Run the configuration script
.\scripts\configure-frontend-url.ps1 -FrontendUrl "https://your-app.lovable.dev"
```

Or manually:

```powershell
# Get your Lovable frontend URL (e.g., https://your-app.lovable.dev)
$FRONTEND_URL = "https://your-app.lovable.dev"

# Update the secret
echo -n $FRONTEND_URL | gcloud secrets versions add lovable-frontend-url --data-file=- --project=credovo-eu-apps-nonprod

# Restart orchestration service to pick up the change
gcloud run services update orchestration-service --region=europe-west1 --project=credovo-eu-apps-nonprod
```

## Authentication Options

The backend supports two authentication methods:

### Option 1: Supabase Authentication (Recommended)

If you're using Supabase for authentication in Lovable:

1. **Configure Supabase in Backend**:
   ```powershell
   # Set Supabase URL
   echo -n "https://your-project.supabase.co" | gcloud secrets versions add supabase-url --data-file=- --project=credovo-eu-apps-nonprod
   ```

2. **Frontend Implementation**:
   ```typescript
   import { createClient } from '@supabase/supabase-js';
   
   const supabase = createClient(
     process.env.REACT_APP_SUPABASE_URL!,
     process.env.REACT_APP_SUPABASE_ANON_KEY!
   );
   
   // After sign in
   const { data: { session } } = await supabase.auth.signInWithPassword({
     email: 'user@example.com',
     password: 'password'
   });
   
   const token = session?.access_token;
   
   // Use token for API requests
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

### Option 2: Token Exchange (Legacy)

If you're using Lovable's built-in authentication:

1. **Get User Info from Lovable**:
   ```typescript
   // Get current user from Lovable
   const user = await lovable.getCurrentUser();
   // Returns: { userId: "user-123", email: "user@example.com", name: "John Doe" }
   ```

2. **Exchange for Backend JWT**:
   ```typescript
   const response = await fetch(`${process.env.REACT_APP_API_URL}/api/v1/auth/token`, {
     method: 'POST',
     headers: {
       'Content-Type': 'application/json',
     },
     body: JSON.stringify({
       userId: user.userId,      // Required
       email: user.email,        // Optional
       name: user.name           // Optional
     })
   });
   
   const { token, expiresIn, user: userInfo } = await response.json();
   
   // Store token
   localStorage.setItem('authToken', token);
   ```

3. **Use Token for API Requests**:
   ```typescript
   const token = localStorage.getItem('authToken');
   
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

## Available API Endpoints

### Company Search

```typescript
// Search companies (requires authentication)
const response = await fetch(
  `${process.env.REACT_APP_API_URL}/api/v1/companies/search?query=test&limit=10`,
  {
    headers: {
      'Authorization': `Bearer ${token}`
    }
  }
);

const { companies, count } = await response.json();
```

### KYC/KYB Verification

```typescript
// Initiate KYC
const response = await fetch(
  `${process.env.REACT_APP_API_URL}/api/v1/applications/${applicationId}/kyc/initiate`,
  {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      type: 'individual',
      data: {
        firstName: 'John',
        lastName: 'Doe',
        dateOfBirth: '1990-01-01',
        email: 'john.doe@example.com',
        country: 'GB',
        address: {
          line1: '123 Test Street',
          city: 'London',
          postcode: 'SW1A 1AA',
          country: 'GB'
        }
      }
    })
  }
);

// Check KYC status
const statusResponse = await fetch(
  `${process.env.REACT_APP_API_URL}/api/v1/applications/${applicationId}/kyc/status`,
  {
    headers: {
      'Authorization': `Bearer ${token}`
    }
  }
);
```

### Open Banking (Plaid)

```typescript
// Create Link token
const linkTokenResponse = await fetch(
  `${process.env.REACT_APP_API_URL}/api/v1/applications/${applicationId}/banking/link-token`,
  {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      products: ['transactions', 'auth'],
      redirectUri: window.location.origin
    })
  }
);

const { linkToken } = await linkTokenResponse.json();

// Use linkToken with Plaid Link (frontend SDK)
// After user connects, exchange public token
const exchangeResponse = await fetch(
  `${process.env.REACT_APP_API_URL}/api/v1/applications/${applicationId}/banking/exchange-token`,
  {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      publicToken: publicToken // From Plaid Link
    })
  }
);
```

## CORS Configuration

The backend automatically allows requests from:
- `https://app.lovable.dev` (default)
- `http://localhost:3000` (for local development)
- Any URL set in `LOVABLE_FRONTEND_URL` environment variable

To add your custom frontend URL:

1. **Via Secret Manager**:
   ```powershell
   echo -n "https://your-app.lovable.dev" | gcloud secrets versions add lovable-frontend-url --data-file=- --project=credovo-eu-apps-nonprod
   ```

2. **Update Orchestration Service**:
   ```powershell
   gcloud run services update orchestration-service \
     --region=europe-west1 \
     --update-env-vars LOVABLE_FRONTEND_URL=https://your-app.lovable.dev \
     --project=credovo-eu-apps-nonprod
   ```

## Testing the Connection

### 1. Test Health Endpoint

```typescript
const response = await fetch(`${process.env.REACT_APP_API_URL}/health`);
const health = await response.json();
console.log('Backend health:', health);
```

### 2. Test Authentication

```typescript
// Test token exchange
const response = await fetch(`${process.env.REACT_APP_API_URL}/api/v1/auth/token`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    userId: 'test-user-123',
    email: 'test@example.com'
  })
});

const { token } = await response.json();
console.log('Token received:', token ? 'Success' : 'Failed');
```

### 3. Test Authenticated Endpoint

```typescript
// Test company search with token
const response = await fetch(
  `${process.env.REACT_APP_API_URL}/api/v1/companies/search?query=test&limit=5`,
  {
    headers: {
      'Authorization': `Bearer ${token}`
    }
  }
);

if (response.ok) {
  const data = await response.json();
  console.log('Company search works!', data);
} else {
  console.error('Company search failed:', response.status);
}
```

## Troubleshooting

### CORS Errors

**Error**: `Access to fetch at '...' from origin '...' has been blocked by CORS policy`

**Solution**:
1. Verify `LOVABLE_FRONTEND_URL` is set correctly
2. Check that your frontend URL matches exactly (including https/http)
3. Ensure CORS middleware is enabled in orchestration service

### 401 Unauthorized

**Error**: `401 Unauthorized` when making API requests

**Solution**:
1. Verify token is being sent in `Authorization: Bearer <token>` header
2. Check token hasn't expired (7 days for backend tokens)
3. For Supabase: Verify token is valid and not expired
4. Check backend logs for authentication errors

### 403 Forbidden

**Error**: `403 Forbidden` when accessing endpoints

**Solution**:
1. Verify you're using the correct authentication method
2. Check that the user has proper permissions
3. Ensure the endpoint requires authentication (some endpoints like `/health` don't)

### Connection Timeout

**Error**: Request times out or fails to connect

**Solution**:
1. Verify `REACT_APP_API_URL` is set correctly
2. Check that the orchestration service is running:
   ```powershell
   gcloud run services describe orchestration-service --region=europe-west1 --project=credovo-eu-apps-nonprod
   ```
3. Test the URL directly in browser: `https://orchestration-service-saz24fo3sa-ew.a.run.app/health`

## Next Steps

1. ✅ Set `REACT_APP_API_URL` in Lovable environment variables
2. ✅ Configure authentication (Supabase or Token Exchange)
3. ✅ Test health endpoint
4. ✅ Test authenticated endpoints
5. ✅ Implement API calls in your frontend components

## Additional Resources

- [Authentication Guide](AUTHENTICATION.md) - Detailed authentication documentation
- [API Endpoints](INTEGRATIONS.md) - All available API endpoints
- [Testing Guide](TESTING_GUIDE.md) - How to test the integration
