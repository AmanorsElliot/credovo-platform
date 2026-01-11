# Solution When Exemptions Aren't Available

## The Problem

The `iam.allowedPolicyMemberDomains` policy blocks `allUsers` because:
- It only accepts domains or Google Workspace customer IDs (like `C001926vp`)
- `allUsers` is a special IAM member, not a domain
- Exemptions are not available for this constraint type in the console

## Solution Options

### Option 1: Contact Organization Admin (Recommended)

Since exemptions aren't available in the console, you'll need to request an exemption via:
- **GCP Support** - Open a support case requesting an exemption
- **Organization Admin** - They may be able to create exemptions via API
- **Policy Administrator** - They might have access to exemption features

**Request Details:**
- **Constraint**: `iam.allowedPolicyMemberDomains`
- **Resource**: `projects/858440156644/locations/europe-west1/services/proxy-service`
- **Justification**: Required for Supabase Edge Function integration. Service only forwards authenticated requests.

### Option 2: Use API to Create Exemption

Try creating an exemption via the Organization Policy API:

```powershell
# First, get the current policy
$policy = gcloud org-policies describe iam.allowedPolicyMemberDomains `
  --project=credovo-eu-apps-nonprod `
  --format=json

# Then use the API to add exemption (requires proper permissions)
# This might require organization-level permissions
```

### Option 3: Modify Policy to Allow allUsers (Not Recommended)

⚠️ **Warning**: This would allow `allUsers` for ALL resources in the organization, which may violate security policies.

If absolutely necessary and approved by security:
1. Edit the "Domain restricted sharing" policy
2. Add a rule that allows `allUsers` (if the policy accepts it)
3. This would apply organization-wide

### Option 4: Use Cloud Function Instead of Cloud Run

Deploy the proxy as a **Cloud Function** instead of Cloud Run:
- Cloud Functions might have different policy restrictions
- May allow public access more easily
- Requires rewriting the proxy service

### Option 5: Use API Gateway

Use **API Gateway** or **Cloud Endpoints**:
- These services might have different policy restrictions
- Can act as a proxy layer
- May allow public access configuration

### Option 6: Temporary Workaround - Service Account Authentication

If you can't make the proxy public, you could:
1. Have the Edge Function authenticate using a service account key (not recommended for security)
2. Or use a different authentication mechanism

## Recommended Next Steps

1. **Contact your organization admin** or GCP support to request an exemption
2. **Document the requirement** - Explain why public access is needed
3. **Provide security justification** - The proxy only forwards authenticated requests
4. **Request exemption via API** if you have the necessary permissions

## Alternative Architecture

If exemptions cannot be obtained, consider:
- Using **Cloud Functions** for the proxy (different policy restrictions)
- Using **API Gateway** as a proxy layer
- Modifying the Edge Function to use a different authentication method

## Verification

Once an exemption is granted (via support/admin), verify:

```powershell
# Grant public access
gcloud run services add-iam-policy-binding proxy-service `
  --region=europe-west1 `
  --member="allUsers" `
  --role="roles/run.invoker" `
  --project=credovo-eu-apps-nonprod `
  --condition=None

# Test access
$proxyUrl = "https://proxy-service-saz24fo3sa-ew.a.run.app"
Invoke-RestMethod -Uri "$proxyUrl/health"
```
