# Cloud Build Troubleshooting Guide

## Builds Stuck in "Scheduled" Status

If builds are showing as "scheduled" but not progressing, this usually indicates one of the following issues:

### 1. GitHub Connection Not Authorized

**Symptoms:**
- Builds appear in "scheduled" status
- No build logs or progress
- Connection status shows "Configuration incomplete"

**Solution:**
1. Go to: https://console.cloud.google.com/cloud-build/connections?project=credovo-eu-apps-nonprod
2. Click on the `credovo-platform` connection
3. Click **"Grant access"** or **"Authorize"** to complete OAuth
4. Authorize Google Cloud Build to access your GitHub repository
5. Wait for status to change to "Ready"

### 2. Trigger Configuration Issues

**Symptoms:**
- Builds scheduled but never start
- No build logs

**Check:**
```powershell
# List all triggers
gcloud builds triggers list --region=europe-west1 --project=credovo-eu-apps-nonprod

# Check trigger details
gcloud builds triggers describe deploy-orchestration-service --region=europe-west1 --project=credovo-eu-apps-nonprod
```

**Common Issues:**
- Branch pattern doesn't match (`^main$` vs `main`)
- Build config file path is incorrect
- Substitution variables are missing

### 3. Service Account Permissions

**Symptoms:**
- Builds start but fail immediately
- Permission denied errors

**Required Permissions:**
- `roles/cloudbuild.builds.editor` - To create builds
- `roles/run.admin` - To deploy to Cloud Run
- `roles/artifactregistry.writer` - To push images
- `roles/iam.serviceAccountUser` - To use service accounts

**Check:**
```powershell
gcloud projects get-iam-policy credovo-eu-apps-nonprod \
  --flatten="bindings[].members" \
  --filter="bindings.members:github-actions@credovo-eu-apps-nonprod.iam.gserviceaccount.com"
```

### 4. Quota/Limit Issues

**Symptoms:**
- Builds queued but never start
- No error messages

**Check:**
```powershell
# Check build quota
gcloud compute project-info describe --project=credovo-eu-apps-nonprod --format="value(quotas)"

# Check concurrent build limit
gcloud builds list --filter="status=QUEUED OR status=WORKING" --limit=10
```

**Solution:**
- Wait for other builds to complete
- Cancel stuck builds: `gcloud builds cancel BUILD_ID`
- Request quota increase if needed

### 5. Cloud Build API Not Enabled

**Symptoms:**
- Builds can't be created
- API errors

**Check:**
```powershell
gcloud services list --enabled --filter="name:cloudbuild.googleapis.com"
```

**Enable if needed:**
```powershell
gcloud services enable cloudbuild.googleapis.com --project=credovo-eu-apps-nonprod
```

## Quick Fixes

### Cancel Stuck Builds
```powershell
# List stuck builds
gcloud builds list --filter="status=QUEUED" --limit=10

# Cancel a specific build
gcloud builds cancel BUILD_ID --project=credovo-eu-apps-nonprod
```

### Retry a Build
```powershell
# Retry a failed build
gcloud builds submit --config=services/orchestration-service/cloudbuild.yaml \
  --substitutions=_REGION=europe-west1,_ARTIFACT_REGISTRY=credovo-services,_SERVICE_NAME=orchestration-service \
  --project=credovo-eu-apps-nonprod
```

### Recreate Triggers
```powershell
# Delete and recreate a trigger
gcloud builds triggers delete deploy-orchestration-service \
  --region=europe-west1 \
  --project=credovo-eu-apps-nonprod

# Then recreate using setup script
.\scripts\setup-parallel-build-trigger.ps1
```

## Common Error Messages

### "Connection not found"
- The GitHub connection doesn't exist or was deleted
- Recreate the connection in GCP Console

### "Permission denied"
- Service account lacks required permissions
- Grant the roles listed above

### "Build config file not found"
- The `cloudbuild.yaml` path is incorrect
- Check the path in trigger configuration

### "Substitution variable not found"
- Required substitution variables are missing
- Check trigger configuration for `_REGION`, `_ARTIFACT_REGISTRY`, `_SERVICE_NAME`

## Debugging Steps

1. **Check build logs:**
   ```powershell
   gcloud builds log BUILD_ID --project=credovo-eu-apps-nonprod
   ```

2. **Check trigger configuration:**
   ```powershell
   gcloud builds triggers describe TRIGGER_NAME --region=europe-west1 --project=credovo-eu-apps-nonprod
   ```

3. **Test build manually:**
   ```powershell
   gcloud builds submit --config=services/orchestration-service/cloudbuild.yaml \
     --substitutions=_REGION=europe-west1,_ARTIFACT_REGISTRY=credovo-services,_SERVICE_NAME=orchestration-service
   ```

4. **Check connection status:**
   ```powershell
   gcloud builds connections describe credovo-platform --region=europe-west1 --project=credovo-eu-apps-nonprod
   ```

## Still Stuck?

1. Check Cloud Build console: https://console.cloud.google.com/cloud-build/builds?project=credovo-eu-apps-nonprod
2. Check build logs for specific error messages
3. Verify GitHub repository is accessible
4. Ensure you have proper IAM permissions
5. Check GCP quotas and limits

