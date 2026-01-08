# Lovable Frontend

This directory contains the Lovable frontend project configuration.

## Setup

1. Create a new Lovable project at https://lovable.dev
2. Connect this GitHub repository
3. Configure Lovable Cloud authentication
4. Set environment variables:
   - `REACT_APP_API_URL`: Orchestration service URL (e.g., `https://orchestration-service-xxx.run.app`)

## Environment Variables

The frontend will need to be configured with:
- `REACT_APP_API_URL`: Backend API endpoint for the orchestration service

## Authentication Flow

**Using Supabase through Lovable**: Supabase provides JWT tokens that can be used directly with the backend.

1. **Authenticate with Supabase** (handled by Lovable)
2. **Get JWT token from Supabase session**
3. **Use Supabase JWT** for all API requests (backend validates using JWKS)

### Example Implementation

```typescript
import { supabase } from "@/integrations/supabase/client";

// 1. Get the current session (after user logs in)
const { data: { session } } = await supabase.auth.getSession();

// 2. Extract JWT token from session
const jwtToken = session?.access_token;

// 3. Use token for API requests
const apiResponse = await fetch(`${process.env.REACT_APP_API_URL}/api/v1/applications/123/kyc/initiate`, {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${jwtToken}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    type: 'individual',
    data: { /* ... */ }
  })
});

// Handle token refresh automatically
supabase.auth.onAuthStateChange((event, session) => {
  if (session) {
    // Token automatically refreshed by Supabase
    const newToken = session.access_token;
    // Use newToken for subsequent requests
  }
});
```

## Integration

The frontend should:
1. Authenticate users via Supabase (through Lovable)
2. Get JWT token from Supabase session (`session.access_token`)
3. Send authenticated requests to the orchestration service with Supabase JWT
4. Handle token refresh (Supabase handles this automatically)
5. Display KYC/KYB status and results

## Documentation

For detailed authentication documentation, see:
- [Authentication Guide](../../docs/AUTHENTICATION.md)
