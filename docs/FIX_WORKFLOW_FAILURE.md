# Fixing GitHub Actions Workflow Failure

## Current Status

The "Deploy to Cloud Run" workflow failed after 10 seconds, which typically indicates:
- Missing GitHub secrets (Workload Identity)
- Authentication failure
- Configuration issue

## Step 1: Check Workflow Logs

1. Click on the failed workflow run in GitHub Actions
2. Expand the failed job to see the error message
3. Look for errors like:
   - "Missing required secret: GCP_WIF_PROVIDER"
   - "Authentication failed"
   - "Permission denied"

## Step 2: Set Up Workload Identity (If Not Done)

The workflow requires these GitHub secrets:

### Required Secrets

1. **`GCP_WIF_PROVIDER`**
   - Format: `projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/POOL_ID/providers/PROVIDER_ID`
   - Example: `projects/123456789/locations/global/workloadIdentityPools/github-actions-pool-v2/providers/github-provider`

2. **`GCP_WIF_SERVICE_ACCOUNT`**
   - Format: `SERVICE_ACCOUNT@PROJECT_ID.iam.gserviceaccount.com`
   - Example: `github-actions@credovo-eu-apps-nonprod.iam.gserviceaccount.com`

### How to Get These Values

#### Get Workload Identity Provider

```powershell
# List workload identity pools
gcloud iam workload-identity-pools list --location=global --project=credovo-eu-apps-nonprod

# List providers in a pool
gcloud iam workload-identity-pools providers list \
  --workload-identity-pool=github-actions-pool-v2 \
  --location=global \
  --project=credovo-eu-apps-nonprod

# Get full provider name
gcloud iam workload-identity-pools providers describe github-provider \
  --workload-identity-pool=github-actions-pool-v2 \
  --location=global \
  --project=credovo-eu-apps-nonprod \
  --format="value(name)"
```

#### Get Service Account

```powershell
# List service accounts
gcloud iam service-accounts list --project=credovo-eu-apps-nonprod

# If github-actions service account doesn't exist, create it:
gcloud iam service-accounts create github-actions \
  --display-name="GitHub Actions Service Account" \
  --project=credovo-eu-apps-nonprod
```

### Add Secrets to GitHub

1. Go to: https://github.com/AmanorsElliot/credovo-platform/settings/secrets/actions
2. Click **"New repository secret"**
3. Add each secret:
   - Name: `GCP_WIF_PROVIDER`
   - Value: (from command above)
4. Repeat for `GCP_WIF_SERVICE_ACCOUNT`

## Step 3: Grant Permissions to Service Account

The service account needs these roles:

```powershell
$serviceAccount = "github-actions@credovo-eu-apps-nonprod.iam.gserviceaccount.com"

# Cloud Run admin (to deploy services)
gcloud projects add-iam-policy-binding credovo-eu-apps-nonprod \
  --member="serviceAccount:$serviceAccount" \
  --role="roles/run.admin"

# Artifact Registry writer (to push images)
gcloud projects add-iam-policy-binding credovo-eu-apps-nonprod \
  --member="serviceAccount:$serviceAccount" \
  --role="roles/artifactregistry.writer"

# Service Account User (to use service accounts)
gcloud projects add-iam-policy-binding credovo-eu-apps-nonprod \
  --member="serviceAccount:$serviceAccount" \
  --role="roles/iam.serviceAccountUser"
```

## Step 4: Re-run the Workflow

1. Go back to: https://github.com/AmanorsElliot/credovo-platform/actions
2. Click on "Deploy to Cloud Run" workflow
3. Click **"Run workflow"** button
4. Select branch: `main`
5. Click **"Run workflow"**

## Common Issues

### Issue: "Missing required secret"

**Solution:** Add the missing secret in GitHub Settings → Secrets → Actions

### Issue: "Permission denied" or "403 Forbidden"

**Solution:** 
1. Verify service account has correct roles (see Step 3)
2. Check Workload Identity binding is correct

### Issue: "Workload Identity Pool not found"

**Solution:** Create the workload identity pool and provider (see `docs/WORKLOAD_IDENTITY_SETUP.md`)

### Issue: "Docker build failed"

**Solution:**
- Check Dockerfile syntax
- Verify all dependencies are in package.json
- Check build logs for specific errors

## Quick Checklist

- [ ] Checked workflow logs for specific error
- [ ] Added `GCP_WIF_PROVIDER` secret to GitHub
- [ ] Added `GCP_WIF_SERVICE_ACCOUNT` secret to GitHub
- [ ] Service account has `roles/run.admin`
- [ ] Service account has `roles/artifactregistry.writer`
- [ ] Service account has `roles/iam.serviceAccountUser`
- [ ] Re-ran the workflow

## Next Steps After Fix

Once the workflow succeeds:
1. Verify services are deployed: Check service images (should not be `gcr.io/cloudrun/hello`)
2. Run test script: `.\scripts\test-backend-connection.ps1`
3. Test from frontend: Use browser console in Lovable app

