# Update Edge Function to Use Proxy Service

## Problem

The Edge Function is still calling the orchestration service directly, which causes 401 errors because:
- Cloud Run IAM blocks requests without Google Identity Tokens
- Edge Functions only have Supabase JWT tokens
- The orchestration service requires authentication

## Solution

Update the Edge Function to call the **proxy service** instead of the orchestration service directly.

## Step 1: Get Proxy Service URL

The proxy service URL is: **`https://proxy-service-saz24fo3sa-ew.a.run.app`**

To verify it's accessible:
```powershell
# Get the proxy service URL
$proxyUrl = (gcloud run services describe proxy-service `
    --region=europe-west1 `
    --project=credovo-eu-apps-nonprod `
    --format="value(status.url)")

Write-Host "Proxy Service URL: $proxyUrl"

# Test health endpoint
Invoke-RestMethod -Uri "$proxyUrl/health"
```

## Step 2: Update Edge Function Code

In your Edge Function (`supabase/functions/applications/index.ts`), change from:

```typescript
// ❌ OLD - Calling orchestration service directly
const backendUrl = Deno.env.get("BACKEND_API_URL") || 
  "https://orchestration-service-saz24fo3sa-ew.a.run.app";

const backendResponse = await fetch(`${backendUrl}/api/v1/applications`, {
  method: "POST",
  headers: {
    "Authorization": `Bearer ${token}`, // This will fail - Cloud Run IAM blocks it
    "Content-Type": "application/json",
  },
  body: JSON.stringify(body),
});
```

To:

```typescript
// ✅ NEW - Calling proxy service
const proxyUrl = Deno.env.get("PROXY_SERVICE_URL") || 
  "https://proxy-service-saz24fo3sa-ew.a.run.app";

const backendResponse = await fetch(`${proxyUrl}/api/v1/applications`, {
  method: "POST",
  headers: {
    "Authorization": `Bearer ${token}`, // Supabase JWT - proxy will forward this
    "Content-Type": "application/json",
  },
  body: JSON.stringify(body),
});
```

## Step 3: Set Environment Variable in Supabase

1. Go to your Supabase project dashboard
2. Navigate to **Edge Functions** → **Settings** or **Environment Variables**
3. Add a new environment variable:
   - **Name**: `PROXY_SERVICE_URL`
   - **Value**: `https://proxy-service-saz24fo3sa-ew.a.run.app`

Or use the Supabase CLI:

```bash
supabase secrets set PROXY_SERVICE_URL=https://proxy-service-saz24fo3sa-ew.a.run.app
```

## Complete Edge Function Example

Here's a complete example of the updated Edge Function:

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Extract the authorization header from the incoming request
    const authHeader = req.headers.get("Authorization");
    
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return new Response(
        JSON.stringify({ error: "Missing or invalid authorization header" }),
        { 
          status: 401, 
          headers: { ...corsHeaders, "Content-Type": "application/json" } 
        }
      );
    }

    // Extract the token
    const token = authHeader.substring(7);

    // Create Supabase client to verify the token
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
        { 
          status: 401, 
          headers: { ...corsHeaders, "Content-Type": "application/json" } 
        }
      );
    }

    // Parse request body
    const body = await req.json();
    const { type, data } = body;

    // ✅ IMPORTANT: Use PROXY_SERVICE_URL instead of BACKEND_API_URL
    const proxyUrl = Deno.env.get("PROXY_SERVICE_URL") || 
      "https://proxy-service-saz24fo3sa-ew.a.run.app";

    // Call proxy service (which will forward to orchestration service)
    const backendResponse = await fetch(`${proxyUrl}/api/v1/applications`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${token}`, // Supabase JWT - proxy forwards this
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        type: type || "business_mortgage",
        data: data || {},
      }),
    });

    if (!backendResponse.ok) {
      const errorText = await backendResponse.text();
      console.error("Backend error:", errorText);
      
      return new Response(
        JSON.stringify({ 
          error: "Backend request failed",
          status: backendResponse.status,
          message: `Backend returned ${backendResponse.status}: ${errorText}` 
        }),
        { 
          status: backendResponse.status,
          headers: { ...corsHeaders, "Content-Type": "application/json" } 
        }
      );
    }

    const backendData = await backendResponse.json();
    
    return new Response(
      JSON.stringify(backendData),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("Error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { 
        status: 500, 
        headers: { ...corsHeaders, "Content-Type": "application/json" } 
      }
    );
  }
});
```

## Step 4: Deploy Updated Edge Function

```bash
# Deploy the updated Edge Function
supabase functions deploy applications
```

## Step 5: Test

After deploying, test the Edge Function:

```bash
# Get a Supabase JWT token (from your frontend or Supabase dashboard)
TOKEN="your-supabase-jwt-token"

# Test the Edge Function
curl -X POST https://your-project.supabase.co/functions/v1/applications \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"type": "business_mortgage", "data": {}}'
```

## Verification Checklist

- [ ] Proxy service is deployed and accessible
- [ ] Edge Function code uses `PROXY_SERVICE_URL` instead of `BACKEND_API_URL`
- [ ] `PROXY_SERVICE_URL` environment variable is set in Supabase
- [ ] Edge Function is deployed with updated code
- [ ] Test request succeeds (no 401 error)

## Troubleshooting

If you still get 401 errors:

1. **Verify proxy service URL is correct:**
   ```powershell
   gcloud run services describe proxy-service `
     --region=europe-west1 `
     --project=credovo-eu-apps-nonprod `
     --format="value(status.url)"
   ```

2. **Test proxy service directly:**
   ```powershell
   $proxyUrl = "https://proxy-service-saz24fo3sa-ew.a.run.app"
   $token = "your-supabase-jwt-token"
   Invoke-RestMethod -Uri "$proxyUrl/health"
   Invoke-RestMethod -Uri "$proxyUrl/api/v1/applications" `
     -Method POST `
     -Headers @{
       "Authorization" = "Bearer $token"
       "Content-Type" = "application/json"
     } `
     -Body (@{type="business_mortgage";data=@{}} | ConvertTo-Json)
   ```

3. **Check Edge Function logs in Supabase dashboard** for errors

4. **Verify orchestration service has SUPABASE_URL configured:**
   ```powershell
   gcloud run services describe orchestration-service `
     --region=europe-west1 `
     --project=credovo-eu-apps-nonprod `
     --format="value(spec.template.spec.containers[0].env)" | 
     Select-String "SUPABASE"
   ```

## Architecture Flow

```
Frontend
  ↓ (Supabase JWT in Authorization header)
Supabase Edge Function
  ↓ (forwards Supabase JWT)
Proxy Service (public, allows Supabase JWT)
  ↓ (service account auth + forwards JWT in X-User-Token)
Orchestration Service (authenticated, validates Supabase JWT)
  ↓
Application Logic
```
