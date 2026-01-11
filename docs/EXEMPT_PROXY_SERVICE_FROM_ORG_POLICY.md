# Exempt Proxy Service from Organization Policy

## Overview

The proxy service needs to be exempted from the `constraints/gcp.resourceLocations` organization policy to allow public (`allUsers`) access. This guide walks you through the process in the GCP Console.

## Step-by-Step Instructions

### Step 1: Navigate to Organization Policies

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your organization (or folder if policies are set at folder level)
3. Navigate to **IAM & Admin** → **Organization Policies**
   - Or go directly: `https://console.cloud.google.com/iam-admin/orgpolicies`

### Step 2: Find the Resource Locations Constraint

1. In the Organization Policies page, look for **"Restrict resource locations"** or search for `gcp.resourceLocations`
2. Click on the policy to view its details
3. Note the current policy settings

### Step 3: Create an Exemption

1. In the policy details page, look for **"Exemptions"** tab or section
2. Click **"Add Exemption"** or **"Create Exemption"** button
3. Fill in the exemption details:

   **Exemption Name:**
   ```
   proxy-service-public-access
   ```

   **Resource:**
   ```
   projects/858440156644/locations/europe-west1/services/proxy-service
   ```
   
   Or use the full resource path:
   ```
   //run.googleapis.com/projects/858440156644/locations/europe-west1/services/proxy-service
   ```

   **Reason/Justification:**
   ```
   Required for Supabase Edge Function integration. 
   The proxy service only forwards authenticated requests (requires Supabase JWT token). 
   Application layer enforces authentication. 
   No alternative architecture that maintains security boundaries.
   ```

4. Click **"Save"** or **"Create"**

### Alternative: Create Exemption via gcloud CLI

If you prefer using the command line:

```powershell
# Create the exemption
gcloud org-policies set-policy infrastructure/terraform/org-policy-exemption.json \
  --project=credovo-eu-apps-nonprod

# Or create exemption directly
gcloud alpha resource-manager org-policies set \
  --project=credovo-eu-apps-nonprod \
  --policy-name=constraints/gcp.resourceLocations \
  --exemption-name=proxy-service-public-access \
  --exemption-resource="//run.googleapis.com/projects/858440156644/locations/europe-west1/services/proxy-service" \
  --exemption-reason="Required for Supabase Edge Function integration"
```

### Step 4: Grant Public Access to Proxy Service

After the exemption is created, grant public access:

```powershell
gcloud run services add-iam-policy-binding proxy-service `
  --region=europe-west1 `
  --member="allUsers" `
  --role="roles/run.invoker" `
  --project=credovo-eu-apps-nonprod `
  --condition=None
```

### Step 5: Verify Public Access

Test that the proxy service is now publicly accessible:

```powershell
$proxyUrl = "https://proxy-service-saz24fo3sa-ew.a.run.app"

# Test health endpoint
Invoke-RestMethod -Uri "$proxyUrl/health"

# Should return: {"status":"healthy","service":"proxy-service"}
```

### Step 6: Verify IAM Policy

Check that `allUsers` has access:

```powershell
gcloud run services get-iam-policy proxy-service `
  --region=europe-west1 `
  --project=credovo-eu-apps-nonprod
```

You should see:
```json
{
  "bindings": [
    {
      "members": [
        "allUsers"
      ],
      "role": "roles/run.invoker"
    }
  ]
}
```

## Troubleshooting

### If "Add Exemption" Button is Not Visible

1. Check that you have **Organization Policy Administrator** role
2. Verify you're viewing the policy at the correct level (organization/folder/project)
3. Some policies may require using the API or gcloud CLI

### If Exemption Creation Fails

Try creating it at the project level instead:

1. Navigate to the **project** (not organization)
2. Go to **IAM & Admin** → **Organization Policies**
3. Find the policy and create exemption there

### If Policy is Set at Folder Level

1. Navigate to the **folder** where the policy is set
2. Create the exemption at that folder level
3. The exemption will apply to resources in that folder

## Alternative: Update Policy to Allow Specific Services

If exemptions aren't supported, you may need to update the policy itself to allow public access for specific services. This requires organization admin permissions.

## After Exemption is Applied

1. ✅ Proxy service will be publicly accessible
2. ✅ Edge Function can call proxy service
3. ✅ Update Edge Function to use `PROXY_SERVICE_URL` (see `docs/UPDATE_EDGE_FUNCTION.md`)
4. ✅ Test end-to-end flow

## Security Note

The proxy service is safe to make public because:
- ✅ Requires Supabase JWT token in Authorization header
- ✅ Only forwards requests (doesn't process data)
- ✅ Orchestration service validates JWT before processing
- ✅ All requests are logged for audit

## Next Steps

After granting public access:

1. **Update Edge Function** - Use `PROXY_SERVICE_URL` environment variable
2. **Test** - Verify Edge Function → Proxy → Orchestration flow works
3. **Monitor** - Check logs to ensure requests are flowing correctly
