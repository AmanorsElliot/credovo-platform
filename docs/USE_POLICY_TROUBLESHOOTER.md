# Using Policy Troubleshooter for Proxy Service Access

## Step-by-Step Instructions

### Step 1: Fill in Principal

In the "Principal" section:
- **Principal email**: Enter `allUsers`
  - Note: Some versions might require a different format. If `allUsers` doesn't work, try:
    - `allUsers@`
    - Or leave it empty if the tool doesn't accept `allUsers`

### Step 2: Add Resource Permission Pair

In the "Resource permission pairs" section:

**Q Resource 1:**
- Enter: `projects/858440156644/locations/europe-west1/services/proxy-service`
- Or use the "Browse" button to navigate to the Cloud Run service
- Full path: `//run.googleapis.com/projects/858440156644/locations/europe-west1/services/proxy-service`

**Q Permission 1:**
- Enter: `run.services.getIamPolicy`
- Or: `run.services.setIamPolicy` (to check if we can modify IAM)
- Or: `run.services.invoke` (to check if we can invoke the service)

### Step 3: Check Access

Click the **"Check access"** button.

## What to Look For

The troubleshooter will show:

1. **If access is denied**: It will list which organization policies are blocking it
2. **Policy violations**: It will show the exact constraint blocking access (likely `iam.allowedPolicyMemberDomains`)
3. **Missing permissions**: It will show if there are other IAM permission issues

## Alternative: Check for Service Account

You can also check if the proxy service's service account has the right permissions:

**Principal**: `proxy-service@credovo-eu-apps-nonprod.iam.gserviceaccount.com`

**Resource**: `projects/858440156644/locations/europe-west1/services/orchestration-service`

**Permission**: `run.services.invoke`

This will verify that the proxy service can call the orchestration service (which should work).

## Expected Results

For `allUsers` on the proxy service:
- ❌ **Expected**: Access denied due to `iam.allowedPolicyMemberDomains` constraint
- This confirms the organization policy is blocking it

For the proxy service account on orchestration service:
- ✅ **Expected**: Access allowed (service account should have `roles/run.invoker`)

## Next Steps After Troubleshooting

Once you see the results:
1. **Note the exact constraint** blocking access
2. **Document the policy violation** for your support request
3. **Use the information** to create a more targeted support case
