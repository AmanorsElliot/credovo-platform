# How to Check Deployment Status

## Quick Check Script

Run the PowerShell script:

```powershell
.\scripts\check-deployment-status.ps1
```

This will show:
- Current image for each service
- Whether it's using placeholder or real code
- Service URLs
- Recent Artifact Registry images

## Manual Checks

### 1. Check Service Images

```powershell
gcloud run services describe orchestration-service --region=europe-west1 --project=credovo-eu-apps-nonprod --format="value(spec.template.spec.containers[0].image)"
```

**Expected Results:**
- ❌ `gcr.io/cloudrun/hello` = Placeholder (not deployed)
- ✅ `europe-west1-docker.pkg.dev/credovo-eu-apps-nonprod/credovo-services/orchestration-service:...` = Deployed!

### 2. Check GitHub Actions

1. Go to: https://github.com/AmanorsElliot/credovo-platform/actions
2. Look for the **"Deploy to Cloud Run"** workflow
3. Check the latest run:
   - ✅ Green checkmark = Success
   - ❌ Red X = Failed (check logs)
   - 🟡 Yellow circle = In progress

### 3. Check Artifact Registry

```powershell
gcloud artifacts docker images list europe-west1-docker.pkg.dev/credovo-eu-apps-nonprod/credovo-services/orchestration-service --limit=5
```

If images exist here, they've been built. Check if they're deployed to Cloud Run.

### 4. Check Cloud Run Revisions

```powershell
gcloud run revisions list --service=orchestration-service --region=europe-west1 --project=credovo-eu-apps-nonprod --limit=5
```

This shows recent deployments and when they were created.

## What to Look For

### ✅ Success Indicators

- Service image starts with `europe-west1-docker.pkg.dev/...`
- GitHub Actions workflow shows green checkmark
- Artifact Registry has recent images
- Cloud Run revisions show recent timestamps

### ❌ Not Deployed Yet

- Service image is `gcr.io/cloudrun/hello`
- No images in Artifact Registry
- GitHub Actions workflow hasn't run or failed
- No recent Cloud Run revisions

## Troubleshooting

### If GitHub Actions Hasn't Run

1. **Check if Workload Identity is configured:**
   - Go to: https://github.com/AmanorsElliot/credovo-platform/settings/secrets/actions
   - Verify `GCP_WIF_PROVIDER` and `GCP_WIF_SERVICE_ACCOUNT` exist

2. **Check workflow file:**
   - Verify `.github/workflows/deploy.yml` exists
   - Check if it triggers on push to `main`

3. **Manually trigger workflow:**
   - Go to Actions tab
   - Click "Deploy to Cloud Run"
   - Click "Run workflow"

### If GitHub Actions Failed

1. **Check workflow logs:**
   - Click on the failed run
   - Expand failed step
   - Look for error messages

2. **Common issues:**
   - Missing GitHub secrets (Workload Identity)
   - Docker build failures
   - Permission errors
   - Region constraint errors

### If Code is Deployed but Tests Fail

1. **Check service logs:**
   ```powershell
   gcloud run services logs read orchestration-service --region=europe-west1 --project=credovo-eu-apps-nonprod --limit=50
   ```

2. **Test health endpoint:**
   ```powershell
   .\scripts\test-backend-connection.ps1
   ```

3. **Verify environment variables:**
   ```powershell
   gcloud run services describe orchestration-service --region=europe-west1 --project=credovo-eu-apps-nonprod --format="value(spec.template.spec.containers[0].env)"
   ```

## Next Steps

Once code is deployed:
1. Run test script: `.\scripts\test-backend-connection.ps1`
2. Test from browser console in Lovable app
3. Verify all endpoints work
4. Check service logs for any errors

