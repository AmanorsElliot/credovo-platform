# Supabase Edge Function Authentication Guide

## Problem

When a Supabase Edge Function calls the backend API, it receives a `401 Unauthorized` error because the backend requires authentication.

## Solution

The Edge Function must extract the user's JWT token from the Supabase request and forward it to the backend API.

## Implementation

### 1. Extract JWT Token from Supabase Request

In your Edge Function (`supabase/functions/applications/index.ts`), extract the token from the request:

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  try {
    // Extract the authorization header from the incoming request
    const authHeader = req.headers.get("Authorization");
    
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return new Response(
        JSON.stringify({ error: "Missing or invalid authorization header" }),
        { status: 401, headers: { "Content-Type": "application/json" } }
      );
    }

    // Extract the token
    const token = authHeader.substring(7);

    // Create Supabase client to verify the token (optional but recommended)
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      {
        global: {
          headers: { Authorization: authHeader },
        },
      }
    );

    // Verify the user is authenticated
    const {
      data: { user },
      error: userError,
    } = await supabaseClient.auth.getUser();

    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { "Content-Type": "application/json" } }
      );
    }

    // Now call the backend API with the user's token
    const backendUrl = Deno.env.get("BACKEND_API_URL") || "https://orchestration-service-saz24fo3sa-ew.a.run.app";
    
    const backendResponse = await fetch(`${backendUrl}/api/v1/applications`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${token}`, // Forward the user's JWT token
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        // Your application data here
        type: "business_mortgage",
        // ... other fields
      }),
    });

    if (!backendResponse.ok) {
      const errorText = await backendResponse.text();
      console.error("Backend error:", errorText);
      return new Response(
        JSON.stringify({ 
          error: "Failed to create application",
          details: errorText 
        }),
        { 
          status: backendResponse.status,
          headers: { "Content-Type": "application/json" } 
        }
      );
    }

    const data = await backendResponse.json();
    return new Response(JSON.stringify(data), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
```

### 2. Alternative: Use Supabase Service Role (Not Recommended for User Actions)

If you need to make service-to-service calls (not recommended for user-initiated actions), you could use the service role key, but this bypasses user authentication:

```typescript
// NOT RECOMMENDED for user actions - bypasses user authentication
const supabaseAdmin = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
);
```

**Why not recommended**: This bypasses user authentication and doesn't forward the user's identity to the backend.

### 3. Complete Example: Create Application

Here's a complete example for creating an application:

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  try {
    // CORS headers
    const corsHeaders = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    };

    // Handle OPTIONS request
    if (req.method === "OPTIONS") {
      return new Response("ok", { headers: corsHeaders });
    }

    // Extract authorization header
    const authHeader = req.headers.get("Authorization");
    
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return new Response(
        JSON.stringify({ error: "Missing or invalid authorization header" }),
        { 
          status: 401, 
          headers: { 
            ...corsHeaders,
            "Content-Type": "application/json" 
          } 
        }
      );
    }

    const token = authHeader.substring(7);

    // Verify user is authenticated
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      {
        global: {
          headers: { Authorization: authHeader },
        },
      }
    );

    const {
      data: { user },
      error: userError,
    } = await supabaseClient.auth.getUser();

    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { 
          status: 401, 
          headers: { 
            ...corsHeaders,
            "Content-Type": "application/json" 
          } 
        }
      );
    }

    // Parse request body
    const body = await req.json();
    const { type, data } = body;

    // Call backend API
    const backendUrl = Deno.env.get("BACKEND_API_URL") || 
      "https://orchestration-service-saz24fo3sa-ew.a.run.app";
    
    // Note: The backend expects the applicationId in the URL path
    // You may need to generate an applicationId first or use a different endpoint
    const applicationId = `app-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    
    const backendResponse = await fetch(
      `${backendUrl}/api/v1/applications/${applicationId}/kyc/initiate`,
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${token}`, // Forward user's JWT
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          type: type || "individual",
          data: data || {},
        }),
      }
    );

    if (!backendResponse.ok) {
      const errorText = await backendResponse.text();
      console.error("Backend error:", errorText);
      
      return new Response(
        JSON.stringify({ 
          error: "Failed to create application",
          details: errorText 
        }),
        { 
          status: backendResponse.status,
          headers: { 
            ...corsHeaders,
            "Content-Type": "application/json" 
          } 
        }
      );
    }

    const backendData = await backendResponse.json();
    
    return new Response(
      JSON.stringify({ 
        success: true,
        applicationId,
        ...backendData 
      }),
      {
        headers: { 
          ...corsHeaders,
          "Content-Type": "application/json" 
        },
      }
    );
  } catch (error) {
    console.error("Error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { 
        status: 500, 
        headers: { 
          "Access-Control-Allow-Origin": "*",
          "Content-Type": "application/json" 
        } 
      }
    );
  }
});
```

## Backend Configuration

### 1. Ensure Supabase JWKS is Configured

The backend must be configured to validate Supabase JWTs. Check that these environment variables are set:

```powershell
# Check if Supabase URL is set
gcloud run services describe orchestration-service \
  --region=europe-west1 \
  --project=credovo-eu-apps-nonprod \
  --format="value(spec.template.spec.containers[0].env)"

# If not set, configure it:
echo -n "https://your-project.supabase.co" | gcloud secrets versions add supabase-url --data-file=- --project=credovo-eu-apps-nonprod
```

The backend will automatically construct the JWKS URI from `SUPABASE_URL` as:
```
${SUPABASE_URL}/auth/v1/.well-known/jwks.json
```

### 2. Verify Backend Authentication

The backend uses `validateSupabaseJwt` when `SUPABASE_URL` or `SUPABASE_JWKS_URI` is set. Check the logs:

```powershell
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=orchestration-service" \
  --limit 50 \
  --format json \
  --project=credovo-eu-apps-nonprod
```

Look for: `[STARTUP] Auth middleware selected: Supabase`

## Testing

### 1. Test Edge Function Locally

```bash
# In your Supabase project
supabase functions serve applications --env-file .env.local
```

### 2. Test with curl

```bash
# Get a Supabase JWT token (from your frontend or Supabase dashboard)
TOKEN="your-supabase-jwt-token"

# Call the Edge Function
curl -X POST http://localhost:54321/functions/v1/applications \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"type": "business_mortgage"}'
```

### 3. Test Backend Directly

```bash
# Test backend with Supabase JWT
curl -X POST https://orchestration-service-saz24fo3sa-ew.a.run.app/api/v1/applications/test-app/kyc/initiate \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"type": "individual", "data": {"firstName": "Test"}}'
```

## Common Issues

### Issue 1: 401 Unauthorized from Backend

**Cause**: Token not being forwarded or backend not configured for Supabase JWTs

**Solution**:
1. Verify token is extracted: `console.log("Token:", token.substring(0, 20) + "...")`
2. Verify token is forwarded: Check `Authorization` header in backend request
3. Verify backend has `SUPABASE_URL` or `SUPABASE_JWKS_URI` set
4. Check backend logs for JWT validation errors

### Issue 2: Token Expired

**Cause**: Supabase JWT tokens expire (default: 1 hour)

**Solution**: Frontend should refresh tokens automatically. Edge Function should handle token refresh or return a clear error.

### Issue 3: CORS Errors

**Cause**: Backend not allowing Edge Function origin

**Solution**: Add Edge Function origin to `LOVABLE_FRONTEND_URL` or configure CORS to allow Supabase origins.

## Next Steps

1. ✅ Update Edge Function to extract and forward JWT token
2. ✅ Verify backend has `SUPABASE_URL` configured
3. ✅ Test Edge Function locally
4. ✅ Deploy Edge Function
5. ✅ Test from frontend

## Additional Resources

- [Supabase Edge Functions Docs](https://supabase.com/docs/guides/functions)
- [Supabase Auth Docs](https://supabase.com/docs/guides/auth)
- [Backend Authentication Guide](AUTHENTICATION.md)
