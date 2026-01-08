# Setting Up Workload Identity via GCP Console

Since the CLI requires additional permissions, you can set it up via the GCP Console.

## Step 1: Create Workload Identity Pool

1. Go to: https://console.cloud.google.com/iam-admin/workload-identity-pools?project=credovo-eu-apps-nonprod
2. Click **"CREATE POOL"**
3. Fill in:
   - **Pool name**: `github-actions-pool-v2`
   - **Pool ID**: `github-actions-pool-v2` (auto-generated, can edit)
   - **Description**: "GitHub Actions Pool"
   - **Enabled pool**: ✅ ON
4. Click **"CONTINUE"**

## Step 2: Add Provider (IMPORTANT: Select OIDC!)

1. **Select provider type**: Choose **"OpenID Connect (OIDC)"** ⚠️ (NOT SAML!)
2. Click **"CONTINUE"**

## Step 3: Configure Provider

Fill in the provider details:

- **Provider name**: `github-provider`
- **Provider ID**: `github-provider` (auto-generated)
- **Issuer URL**: `https://token.actions.githubusercontent.com`
- **Allowed audiences**: (leave empty or add `sts.googleapis.com`)

### Attribute Mapping

Click **"ADD MAPPING"** and add:

- **Google attribute**: `google.subject`
- **Attribute value**: `assertion.sub`

### Attribute Condition (Optional but Recommended)

Add condition to restrict to your repository:

- **Condition**: `assertion.repository == "AmanorsElliot/credovo-platform"`

Click **"SAVE"**

## Step 4: Grant Permission to Service Account

After the provider is created:

1. Go to: https://console.cloud.google.com/iam-admin/serviceaccounts?project=credovo-eu-apps-nonprod
2. Click on `github-actions@credovo-eu-apps-nonprod.iam.gserviceaccount.com`
3. Go to **"PERMISSIONS"** tab
4. Click **"GRANT ACCESS"**
5. In **"New principals"**, enter:
   ```
   principalSet://iam.googleapis.com/projects/858440156644/locations/global/workloadIdentityPools/github-actions-pool-v2/attribute.repository/AmanorsElliot/credovo-platform
   ```
6. Select role: **"Workload Identity User"** (`roles/iam.workloadIdentityUser`)
7. Click **"SAVE"**

## Step 5: Get Provider Name for GitHub Secret

1. Go back to: https://console.cloud.google.com/iam-admin/workload-identity-pools?project=credovo-eu-apps-nonprod
2. Click on `github-actions-pool-v2`
3. Click on `github-provider`
4. Copy the **"Resource name"** - it should look like:
   ```
   projects/858440156644/locations/global/workloadIdentityPools/github-actions-pool-v2/providers/github-provider
   ```

## Step 6: Add GitHub Secrets

1. Go to: https://github.com/AmanorsElliot/credovo-platform/settings/secrets/actions
2. Add **`GCP_WIF_PROVIDER`**:
   - Value: (the resource name from Step 5)
3. Add **`GCP_WIF_SERVICE_ACCOUNT`**:
   - Value: `github-actions@credovo-eu-apps-nonprod.iam.gserviceaccount.com`

## Common Mistakes

- ❌ Selecting "SAML" instead of "OIDC" - GitHub Actions uses OIDC
- ❌ Wrong issuer URL - must be `https://token.actions.githubusercontent.com`
- ❌ Missing attribute mapping - need `google.subject = assertion.sub`
- ❌ Wrong principal format - must include the attribute path

## Verification

After setup, test by running the GitHub Actions workflow. It should authenticate successfully!

