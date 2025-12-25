# Workload Identity Federation Setup for GitHub Actions

Since the automated script is encountering issues with provider creation, here's a manual setup guide.

## Step 1: Create Workload Identity Pool

The pool `github-actions-pool-v2` should already exist. Verify:

```powershell
gcloud iam workload-identity-pools describe github-actions-pool-v2 --location=global --project=credovo-platform-dev
```

## Step 2: Create Workload Identity Provider (via GCP Console)

1. Go to: https://console.cloud.google.com/iam-admin/workload-identity-pools?project=credovo-platform-dev
2. Click on `github-actions-pool-v2`
3. Click **ADD PROVIDER**
4. Select **OpenID Connect (OIDC)**
5. Configure:
   - **Provider name**: `github-provider`
   - **Issuer URL**: `https://token.actions.githubusercontent.com`
   - **Attribute mapping**:
     - `google.subject` = `assertion.sub`
   - **Attribute condition**: Leave empty (no condition)
6. Click **SAVE**

## Step 3: Grant IAM Permission

After the provider is created, run:

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

## Step 4: Add GitHub Secrets

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

## Alternative: Use Service Account Key (if WIF continues to fail)

If Workload Identity Federation continues to have issues, you can temporarily use a service account key:

1. Request an exception to the organization policy that blocks key creation
2. Or use the `setup-github-secrets.ps1` script (which will fail due to the policy, but you can request an exception)

## Verify Setup

After setup, test by pushing to the main branch or manually triggering the GitHub Actions workflow.

