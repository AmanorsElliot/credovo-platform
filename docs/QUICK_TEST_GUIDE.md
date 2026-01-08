# Quick Test Guide: Frontend-Backend Communication

## Current Status

⚠️ **Note**: The backend is currently using a placeholder image. You'll need to deploy the actual code first (via GitHub Actions or manual deployment) before these tests will work.

## Step 1: Verify Backend is Deployed

Check if the service is using the real code:

```powershell
gcloud run services describe orchestration-service --region=europe-west1 --project=credovo-eu-apps-nonprod --format="value(spec.template.spec.containers[0].image)"
```

**Expected**: Should show an image from Artifact Registry, not `gcr.io/cloudrun/hello`

**If still using placeholder**: Deploy the code first (see `docs/DEPLOYMENT_READY.md`)

## Step 2: Test from Browser Console (Easiest)

Open your Lovable app in the browser and open the developer console (F12), then run:

### Test 1: Health Check (No Auth)

```javascript
fetch('https://orchestration-service-saz24fo3sa-ew.a.run.app/health')
  .then(r => r.json())
  .then(data => {
    console.log('✅ Health check passed:', data);
  })
  .catch(err => {
    console.error('❌ Health check failed:', err);
  });
```

**Expected Result:**
```json
{
  "status": "healthy",
  "service": "orchestration-service"
}
```

### Test 2: Test with Supabase JWT

```javascript
// First, get your Supabase session
import { supabase } from "@/integrations/supabase/client";

const { data: { session } } = await supabase.auth.getSession();

if (!session) {
  console.error('Not logged in');
} else {
  // Test authenticated endpoint
  fetch('https://orchestration-service-saz24fo3sa-ew.a.run.app/api/v1/applications', {
    headers: {
      'Authorization': `Bearer ${session.access_token}`,
      'Content-Type': 'application/json'
    }
  })
  .then(r => {
    if (r.ok) {
      return r.json();
    } else {
      return r.json().then(err => Promise.reject(err));
    }
  })
  .then(data => {
    console.log('✅ Authenticated request successful:', data);
  })
  .catch(err => {
    console.error('❌ Request failed:', err);
  });
}
```

## Step 3: Test from React Component

Create a test component in your Lovable app:

```typescript
// components/TestBackend.tsx
import { useState } from 'react';
import { supabase } from "@/integrations/supabase/client";

export default function TestBackend() {
  const [result, setResult] = useState<string>('');
  const [loading, setLoading] = useState(false);

  const testHealth = async () => {
    setLoading(true);
    try {
      const response = await fetch(`${process.env.REACT_APP_API_URL}/health`);
      const data = await response.json();
      setResult(`✅ Health: ${JSON.stringify(data)}`);
    } catch (error: any) {
      setResult(`❌ Health failed: ${error.message}`);
    } finally {
      setLoading(false);
    }
  };

  const testAuth = async () => {
    setLoading(true);
    try {
      const { data: { session } } = await supabase.auth.getSession();
      
      if (!session) {
        setResult('❌ Not authenticated');
        return;
      }

      const response = await fetch(
        `${process.env.REACT_APP_API_URL}/api/v1/applications`,
        {
          headers: {
            'Authorization': `Bearer ${session.access_token}`,
            'Content-Type': 'application/json'
          }
        }
      );

      if (response.ok) {
        const data = await response.json();
        setResult(`✅ Auth: ${JSON.stringify(data)}`);
      } else {
        const error = await response.json();
        setResult(`❌ Auth failed: ${JSON.stringify(error)}`);
      }
    } catch (error: any) {
      setResult(`❌ Auth error: ${error.message}`);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div>
      <h2>Backend Connection Test</h2>
      <p>API URL: {process.env.REACT_APP_API_URL}</p>
      
      <button onClick={testHealth} disabled={loading}>
        Test Health Endpoint
      </button>
      
      <button onClick={testAuth} disabled={loading}>
        Test Authenticated Endpoint
      </button>
      
      {result && (
        <pre style={{ background: '#f0f0f0', padding: '10px', marginTop: '10px' }}>
          {result}
        </pre>
      )}
    </div>
  );
}
```

## Step 4: Run PowerShell Test Script

```powershell
.\scripts\test-backend-connection.ps1
```

This will test:
- ✅ Health endpoint
- ✅ CORS configuration
- ✅ Authentication endpoints
- ✅ Token exchange (if using backend JWT)
- ✅ Protected endpoints

## Common Issues & Solutions

### Issue: 403 Forbidden

**Cause**: Service is using placeholder image or IAM not configured

**Solution**:
1. Deploy the actual code (see `docs/DEPLOYMENT_READY.md`)
2. Check IAM permissions:
   ```powershell
   gcloud run services get-iam-policy orchestration-service --region=europe-west1 --project=credovo-eu-apps-nonprod
   ```

### Issue: CORS Error

**Error**: `Access to fetch at '...' has been blocked by CORS policy`

**Solution**:
1. Check backend CORS config in `shared/auth/jwt-validator.ts`
2. Verify `LOVABLE_FRONTEND_URL` is set in Cloud Run
3. Add your frontend URL to allowed origins

### Issue: 401 Unauthorized

**Error**: `401 Unauthorized` on authenticated endpoints

**Solution**:
1. Verify you're sending the token: `Authorization: Bearer <token>`
2. Check token is from Supabase session: `session.access_token`
3. Test token verification:
   ```javascript
   fetch(`${process.env.REACT_APP_API_URL}/api/v1/auth/verify`, {
     headers: { 'Authorization': `Bearer ${session.access_token}` }
   })
   .then(r => r.json())
   .then(console.log);
   ```

## Testing Checklist

- [ ] Backend deployed with actual code (not placeholder)
- [ ] Health endpoint returns `200 OK`
- [ ] CORS allows requests from frontend
- [ ] Can get Supabase JWT token
- [ ] Token verification endpoint works
- [ ] Authenticated endpoints accept token
- [ ] Can make requests from browser console
- [ ] Can make requests from React components

## Next Steps After Testing

Once basic connectivity is verified:

1. **Implement API client** in your frontend
2. **Add error handling** for network errors
3. **Add loading states** for async operations
4. **Test full KYC flow** end-to-end
5. **Set up monitoring** and error tracking

## Example API Client

```typescript
// utils/apiClient.ts
import { supabase } from "@/integrations/supabase/client";

const API_URL = process.env.REACT_APP_API_URL;

export class ApiClient {
  private async getAuthHeaders() {
    const { data: { session } } = await supabase.auth.getSession();
    if (!session) {
      throw new Error('Not authenticated');
    }
    return {
      'Authorization': `Bearer ${session.access_token}`,
      'Content-Type': 'application/json'
    };
  }

  async get(endpoint: string) {
    const headers = await this.getAuthHeaders();
    const response = await fetch(`${API_URL}${endpoint}`, {
      method: 'GET',
      headers
    });
    
    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.message || 'Request failed');
    }
    
    return response.json();
  }

  async post(endpoint: string, data: any) {
    const headers = await this.getAuthHeaders();
    const response = await fetch(`${API_URL}${endpoint}`, {
      method: 'POST',
      headers,
      body: JSON.stringify(data)
    });
    
    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.message || 'Request failed');
    }
    
    return response.json();
  }
}

export const api = new ApiClient();
```

**Usage:**
```typescript
import { api } from '@/utils/apiClient';

// Get applications
const applications = await api.get('/api/v1/applications');

// Initiate KYC
const kycResult = await api.post('/api/v1/applications/123/kyc/initiate', {
  type: 'individual',
  data: { /* ... */ }
});
```

