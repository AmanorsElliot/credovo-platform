# Fix: Missing GitHub Secrets Error

## Error Message

```
google-github-actions/auth failed with: the GitHub Action workflow must specify exactly one of "workload_identity_provider" or "credentials_json"!
```

This means the GitHub secrets `GCP_WIF_PROVIDER` and `GCP_WIF_SERVICE_ACCOUNT` are either:
- Not set in GitHub
- Empty/null values
- Not being passed to the workflow

## Quick Fix

### Step 1: Verify Secrets Exist

1. Go to: https://github.com/AmanorsElliot/credovo-platform/settings/secrets/actions
2. Check if these secrets exist:
   - `GCP_WIF_PROVIDER`
   - `GCP_WIF_SERVICE_ACCOUNT`

### Step 2: Get the Values

If secrets don't exist or are empty, get the values:

#### Get Workload Identity Provider

```powershell
# First, check if the pool exists
gcloud iam workload-identity-pools list --location=global --project=credovo-eu-apps-nonprod

# Get the provider name (full path)
gcloud iam workload-identity-pools providers describe github-provider `
  --workload-identity-pool=github-actions-pool-v2 `
  --location=global `
  --project=credovo-eu-apps-nonprod `
  --format="value(name)"
```

**Expected output format:**
```
projects/123456789/locations/global/workloadIdentityPools/github-actions-pool-v2/providers/github-provider
```

#### Get Service Account

```powershell
# Check if service account exists
gcloud iam service-accounts list --project=credovo-eu-apps-nonprod --filter="email:github-actions"

# If it doesn't exist, create it:
gcloud iam service-accounts create github-actions `
  --display-name="GitHub Actions Service Account" `
  --project=credovo-eu-apps-nonprod

# The service account email is:
# github-actions@credovo-eu-apps-nonprod.iam.gserviceaccount.com
```

### Step 3: Add Secrets to GitHub

1. Go to: https://github.com/AmanorsElliot/credovo-platform/settings/secrets/actions
2. Click **"New repository secret"**
3. Add **`GCP_WIF_PROVIDER`**:
   - Name: `GCP_WIF_PROVIDER`
   - Value: (paste the full provider path from Step 2)
   - Click **"Add secret"**
4. Click **"New repository secret"** again
5. Add **`GCP_WIF_SERVICE_ACCOUNT`**:
   - Name: `GCP_WIF_SERVICE_ACCOUNT`
   - Value: `github-actions@credovo-eu-apps-nonprod.iam.gserviceaccount.com`
   - Click **"Add secret"**

### Step 4: Verify Secret Format

**GCP_WIF_PROVIDER should look like:**
```
projects/123456789/locations/global/workloadIdentityPools/github-actions-pool-v2/providers/github-provider
```

**GCP_WIF_SERVICE_ACCOUNT should look like:**
```
github-actions@credovo-eu-apps-nonprod.iam.gserviceaccount.com
```

### Step 5: Grant Service Account Permissions

```powershell
$sa = "github-actions@credovo-eu-apps-nonprod.iam.gserviceaccount.com"

# Cloud Run admin (to deploy services)
gcloud projects add-iam-policy-binding credovo-eu-apps-nonprod `
  --member="serviceAccount:$sa" `
  --role="roles/run.admin"

# Artifact Registry writer (to push images)
gcloud projects add-iam-policy-binding credovo-eu-apps-nonprod `
  --member="serviceAccount:$sa" `
  --role="roles/artifactregistry.writer"

# Service Account User (to use service accounts)
gcloud projects add-iam-policy-binding credovo-eu-apps-nonprod `
  --member="serviceAccount:$sa" `
  --role="roles/iam.serviceAccountUser"
```

### Step 6: Re-run the Workflow

1. Go to: https://github.com/AmanorsElliot/credovo-platform/actions
2. Click on "Deploy to Cloud Run"
3. Click **"Run workflow"** button
4. Select branch: `main`
5. Click **"Run workflow"**

## Troubleshooting

### If Workload Identity Pool Doesn't Exist

You may need to create it first. See `docs/WORKLOAD_IDENTITY_SETUP.md` for detailed instructions.

Quick check:
```powershell
gcloud iam workload-identity-pools list --location=global --project=credovo-eu-apps-nonprod
```

If empty, you need to create the pool and provider.

### If Secrets Still Don't Work

1. **Check secret names are exact:**
   - Must be: `GCP_WIF_PROVIDER` (not `GCP_WIF_PROVIDER_` or `gcp_wif_provider`)
   - Must be: `GCP_WIF_SERVICE_ACCOUNT` (not `GCP_WIF_SERVICE_ACCOUNT_`)

2. **Check for extra spaces:**
   - Copy/paste the values exactly
   - No leading/trailing spaces

3. **Verify repository access:**
   - Secrets are repository-scoped
   - Make sure you're adding them to the correct repository

4. **Check workflow file syntax:**
   - The workflow uses: `${{ secrets.GCP_WIF_PROVIDER }}`
   - Make sure there are no typos in the workflow file

### Alternative: Use Service Account Key (Less Secure)

If Workload Identity is too complex, you can use a service account key (less secure):

1. Create and download a service account key:
```powershell
gcloud iam service-accounts keys create key.json `
  --iam-account=github-actions@credovo-eu-apps-nonprod.iam.gserviceaccount.com `
  --project=credovo-eu-apps-nonprod
```

2. Add the entire JSON content as a GitHub secret named `GCP_SA_KEY`

3. Update the workflow to use:
```yaml
- name: Authenticate to Google Cloud
  uses: google-github-actions/auth@v2
  with:
    credentials_json: ${{ secrets.GCP_SA_KEY }}
```

**Note:** Workload Identity is more secure and recommended for production.

## Verification

After adding secrets, the workflow should:
1. ✅ Authenticate successfully
2. ✅ Build Docker images
3. ✅ Push to Artifact Registry
4. ✅ Deploy to Cloud Run

Check the workflow logs to confirm each step succeeds.

