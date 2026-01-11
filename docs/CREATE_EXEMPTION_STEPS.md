# Create Exemption for Proxy Service - Step by Step

## Step 1: Navigate to Exemptions Tab

1. You're currently on the "Policy details" page for "Domain restricted sharing"
2. **Look at the top of the page** - you should see two tabs:
   - "amanors.com" (currently selected)
   - **"Exemptions"** ← Click this tab!

## Step 2: Create the Exemption

Once you click the "Exemptions" tab:

1. Click **"Add Exemption"** or **"Create Exemption"** button
2. Fill in the exemption details:

   **Exemption Name:**
   ```
   proxy-service-public-access
   ```

   **Resource:**
   ```
   projects/858440156644/locations/europe-west1/services/proxy-service
   ```
   
   Or the full resource path:
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

3. Click **"Save"** or **"Create"**

## Step 3: Grant Public Access

After the exemption is created, run this command:

```powershell
gcloud run services add-iam-policy-binding proxy-service `
  --region=europe-west1 `
  --member="allUsers" `
  --role="roles/run.invoker" `
  --project=credovo-eu-apps-nonprod `
  --condition=None
```

## Step 4: Verify

Test that the proxy service is now accessible:

```powershell
$proxyUrl = "https://proxy-service-saz24fo3sa-ew.a.run.app"
Invoke-RestMethod -Uri "$proxyUrl/health"
```

## If Exemptions Tab is Not Available

If you don't see an "Exemptions" tab, it might mean:
- Exemptions aren't supported for this constraint type
- You need organization-level permissions
- The feature requires a different GCP tier

In that case, you may need to:
1. Contact your organization admin
2. Or check if there's a way to allow `allUsers` through policy conditions/tags
