# Manual Workload Identity Federation Setup

Due to organization policy restrictions, the Workload Identity Provider must be created manually. Follow these steps:

## The Issue

GCP is requiring an attribute condition that references provider claims, but the validation is failing. This appears to be an organization policy or API validation issue.

## Solution: Manual Provider Creation

### Step 1: Create Provider via GCP Console

1. Go to: https://console.cloud.google.com/iam-admin/workload-identity-pools?project=credovo-platform-dev
2. Click on `github-actions-pool-v2`
3. Click **ADD PROVIDER**
4. Select **OpenID Connect (OIDC)**
5. Configure:
   - **Provider name**: `github-provider`
   - **Issuer URL**: `https://token.actions.githubusercontent.com`
   - **Attribute mapping**:
     - `google.subject` = `assertion.sub`
   - **Attribute condition**: **DO NOT ADD ANY CONDITION** - Leave this section completely empty
6. Click **SAVE**

**Important**: If you get an error about conditions, try:
- Refreshing the page and trying again
- Using a different browser
- Or contact your GCP organization admin to review the policy

### Step 2: Grant IAM Permission

After the provider is created, run this command:

```powershell
$projectNumber = "762270842258"
$poolId = "github-actions-pool-v2"
$serviceAccount = "github-actions@credovo-platform-dev.iam.gserviceaccount.com"

$principal = "principalSet://iam.googleapis.com/projects/$projectNumber/locations/global/workloadIdentityPools/$poolId"

gcloud iam service-accounts add-iam-policy-binding $serviceAccount `
    --project=credovo-platform-dev `
    --role="roles/iam.workloadIdentityUser" `
    --member="$principal"
```

### Step 3: Add GitHub Secrets

Go to: https://github.com/AmanorsElliot/credovo-platform/settings/secrets/actions

Add these **Repository Secrets**:

1. **GCP_PROJECT_ID**
   - Value: `credovo-platform-dev`

2. **GCP_WIF_PROVIDER**
   - Value: `projects/762270842258/locations/global/workloadIdentityPools/github-actions-pool-v2/providers/github-provider`

3. **GCP_WIF_SERVICE_ACCOUNT**
   - Value: `github-actions@credovo-platform-dev.iam.gserviceaccount.com`

4. **ARTIFACT_REGISTRY**
   - Value: `credovo-services`

### Step 4: Verify Setup

After completing the above steps, you can verify by:

1. Running Terraform plan (it should now reference the existing provider):
   ```powershell
   cd infrastructure\terraform
   terraform plan
   ```

2. Testing GitHub Actions by pushing to main or manually triggering a workflow

## Alternative: Request Policy Exception

If the manual creation also fails, you may need to:

1. Contact your GCP organization admin
2. Request an exception to the policy that's blocking provider creation
3. Or request an exception to allow service account key creation (less secure but simpler)

## Troubleshooting

If you continue to see the condition error:
- Check if there are any organization policies on Workload Identity Federation
- Verify you have the `iam.workloadIdentityPools.providers.create` permission
- Try creating the provider via the REST API directly
- Contact GCP support with the tracking number from error messages

