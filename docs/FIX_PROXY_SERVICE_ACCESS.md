# Fix Proxy Service Public Access

## The Issue

The proxy service is blocked by an organization policy that prevents `allUsers` from being added to IAM policies. The error you're seeing is:

> "One or more users named in the policy do not belong to a permitted customer, perhaps due to an organization policy."

## Solution Options

### Option 1: Add Exemption for Proxy Service (Recommended)

Since you're viewing the "Domain restricted sharing" policy, you need to find the policy that specifically blocks `allUsers`. This is likely:

- **"Restrict allowed IAM members"** or
- **"Domain restricted sharing"** (which you're currently viewing)

However, `allUsers` is a special member, not a domain. You may need to:

1. **Look for a different policy** that specifically restricts public access
2. **Or add an exemption** to allow `allUsers` for the proxy service

### Option 2: Add Exemption via Policy Conditions

If the policy supports conditions, you can add a condition-based exemption:

1. In the policy you're viewing, look for **"Exemptions"** tab
2. Click **"Add Exemption"**
3. Set:
   - **Resource**: `projects/858440156644/locations/europe-west1/services/proxy-service`
   - **Condition**: (if supported) Allow `allUsers` for this specific service

### Option 3: Use gcloud to Create Exemption

Try creating the exemption via command line:

```powershell
# First, try to identify the exact constraint
gcloud org-policies list --project=credovo-eu-apps-nonprod --format="table(name,spec.rules)"

# Then create exemption (adjust constraint name as needed)
gcloud alpha resource-manager org-policies set \
  --project=credovo-eu-apps-nonprod \
  --policy-name=constraints/iam.allowedPolicyMemberDomains \
  --exemption-name=proxy-service-allusers \
  --exemption-resource="//run.googleapis.com/projects/858440156644/locations/europe-west1/services/proxy-service"
```

### Option 4: Temporarily Allow allUsers in Policy Rules

If exemptions aren't available, you might need to modify the policy rules to allow `allUsers`:

1. In the policy page, go to **"Rules"** section
2. Click **"Add a rule"**
3. Add a rule that allows `allUsers` for the proxy service
   - This might require using a condition/tag-based approach

## Quick Fix: Try Adding allUsers Directly

Sometimes the policy allows it but the UI/CLI needs the right format. Try:

```powershell
# Try with explicit condition
gcloud run services add-iam-policy-binding proxy-service `
  --region=europe-west1 `
  --member="allUsers" `
  --role="roles/run.invoker" `
  --project=credovo-eu-apps-nonprod `
  --condition=None `
  --condition-title="Proxy service public access" `
  --condition-description="Required for Supabase Edge Function integration"
```

## Alternative: Check for Different Policy

The policy blocking `allUsers` might be a different constraint. Check for:

1. **"Restrict public IP access"** - `constraints/compute.restrictPublicIp`
2. **"Restrict allowed IAM members"** - Different from domain restriction
3. **"VPC Service Controls"** - Might block public access

Navigate to: **IAM & Admin** → **Organization Policies** and search for policies containing:
- "public"
- "allUsers" 
- "unauthenticated"

## Verification

After making changes, verify:

```powershell
# Check IAM policy
gcloud run services get-iam-policy proxy-service `
  --region=europe-west1 `
  --project=credovo-eu-apps-nonprod

# Test access
$proxyUrl = "https://proxy-service-saz24fo3sa-ew.a.run.app"
Invoke-RestMethod -Uri "$proxyUrl/health"
```

## Next Steps

1. **Identify the exact policy** blocking `allUsers` (might not be the domain restriction policy)
2. **Create exemption** or modify policy rules
3. **Grant public access** using the command above
4. **Test** the proxy service
5. **Update Edge Function** to use proxy service URL
