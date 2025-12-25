# GitHub Actions Troubleshooting Guide

## Workload Identity Federation Authentication Issues

### Error: "GitHub Actions did not inject $ACTIONS_ID_TOKEN_REQUEST_TOKEN"

This error occurs when GitHub Actions cannot provide the OIDC token needed for Workload Identity Federation.

#### Solution 1: Verify Workflow Permissions

Ensure your workflow file includes the `permissions` block:

```yaml
jobs:
  your-job:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write # Required for Workload Identity Federation
    steps:
      # ... your steps
```

#### Solution 2: Check Repository Settings (CRITICAL)

GitHub has repository-level settings that can override workflow permissions. This is often the root cause:

1. Go to: https://github.com/AmanorsElliot/credovo-platform/settings/actions
2. Scroll down to **"Workflow permissions"** section
3. You have two options:

   **Option A (Recommended):** Set to **"Read and write permissions"**
   - This allows workflows to request OIDC tokens by default
   - Your `permissions` block in workflows will still work
   
   **Option B:** Keep "Read repository contents and packages permissions" BUT:
   - You MUST have `permissions` block with `id-token: write` in EVERY job (which you do)
   - However, some repository settings may still block this
   
4. **IMPORTANT**: After changing this setting, you MUST trigger a NEW workflow run. Old runs won't work.

**If you're still seeing the error after setting permissions:**
- Make sure you clicked "Save" after changing the repository setting
- Trigger a completely NEW workflow run (don't re-run an old one)
- The repository setting change only affects NEW runs

#### Solution 3: Verify Secrets Are Set

Ensure all required secrets are configured:

1. Go to: https://github.com/AmanorsElliot/credovo-platform/settings/secrets/actions
2. Verify these secrets exist:
   - `GCP_PROJECT_ID`
   - `GCP_WIF_PROVIDER`
   - `GCP_WIF_SERVICE_ACCOUNT`
   - `ARTIFACT_REGISTRY`

#### Solution 4: Re-run the Workflow

If you've just fixed the permissions, you need to trigger a NEW workflow run:

1. Go to: https://github.com/AmanorsElliot/credovo-platform/actions
2. Find your workflow
3. Click **Run workflow** (or wait for the next push to trigger it)

Old workflow runs will still show the error - they ran before the fix was applied.

#### Solution 5: Check if Running from Fork

If the workflow is running from a fork, OIDC tokens are not available for security reasons. Ensure the workflow is running from the main repository.

### Common Issues

#### Issue: Permissions added but still failing

**Check:**
- Did you push the changes to the repository?
- Are you looking at a NEW workflow run (not an old one)?
- Is the repository-level setting overriding your workflow permissions?

#### Issue: Authentication succeeds but deployment fails

**Check:**
- Service account has correct IAM roles
- Cloud Run service exists
- Artifact Registry repository exists
- Image was built and pushed successfully

### Verification Steps

1. **Check workflow file syntax:**
   ```bash
   # The permissions block should be at the job level, not workflow level
   jobs:
     job-name:
       permissions:
         id-token: write
   ```

2. **Verify secrets are accessible:**
   - Secrets should be Repository secrets (not Environment secrets) unless using environments
   - Secrets names must match exactly (case-sensitive)

3. **Test authentication:**
   - Add a debug step to your workflow:
   ```yaml
   - name: Debug
     run: |
       echo "Provider: ${{ secrets.GCP_WIF_PROVIDER }}"
       echo "Service Account: ${{ secrets.GCP_WIF_SERVICE_ACCOUNT }}"
   ```

### Still Having Issues?

1. Check GitHub Actions logs for detailed error messages
2. Verify Workload Identity Provider exists in GCP Console
3. Test the IAM binding manually:
   ```powershell
   gcloud iam service-accounts get-iam-policy github-actions@credovo-platform-dev.iam.gserviceaccount.com
   ```
4. Contact support with:
   - Workflow run URL
   - Error message
   - GCP project ID

