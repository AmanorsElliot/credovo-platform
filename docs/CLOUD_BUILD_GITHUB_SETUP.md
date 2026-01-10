# Cloud Build GitHub Integration Setup

This guide shows how to use Cloud Build's native GitHub integration instead of GitHub Actions.

## Benefits

✅ **No Workload Identity setup needed** - Cloud Build handles authentication natively  
✅ **Native GitHub OAuth integration** - Direct connection to GitHub  
✅ **Automatic builds on push/PR** - Built-in trigger management  
✅ **Simpler authentication** - No service account key management  
✅ **Built-in trigger management** - Configure via GCP Console or gcloud CLI  

## Step 1: Complete Repository Connection

The connection `credovo-platform` exists but needs OAuth completion:

1. Go to: https://console.cloud.google.com/cloud-build/connections?project=credovo-eu-apps-nonprod
2. Click on the `credovo-platform` connection
3. Click **"Grant access"** or **"Authorize"** to complete OAuth
4. Authorize Google Cloud Build to access your GitHub repository
5. Wait for the status to change from "Configuration incomplete" to "Ready"

## Step 2: Create Cloud Build Triggers

After the connection is ready, create triggers for each service:

### Option A: Via GCP Console

1. Go to: https://console.cloud.google.com/cloud-build/triggers?project=credovo-eu-apps-nonprod
2. Click **"Create Trigger"**
3. Configure:
   - **Name**: `deploy-orchestration-service`
   - **Event**: Push to a branch
   - **Source**: Select `credovo-platform` connection
   - **Repository**: `AmanorsElliot/credovo-platform`
   - **Branch**: `^main$`
   - **Configuration**: Cloud Build configuration file
   - **Location**: `services/orchestration-service/cloudbuild.yaml`
   - **Substitution variables**:
     - `_REGION`: `europe-west1`
     - `_ARTIFACT_REGISTRY`: `credovo-services`
     - `_SERVICE_NAME`: `orchestration-service`
   - **Service account**: `github-actions@credovo-eu-apps-nonprod.iam.gserviceaccount.com`
4. Click **"Create"**
5. Repeat for `kyc-kyb-service` and `connector-service`

### Option B: Via gcloud CLI

```powershell
# Create trigger for orchestration-service
gcloud builds triggers create github `
  --name="deploy-orchestration-service" `
  --region=europe-west1 `
  --repo-name="credovo-platform" `
  --repo-owner="AmanorsElliot" `
  --branch-pattern="^main$" `
  --build-config="services/orchestration-service/cloudbuild.yaml" `
  --substitutions="_REGION=europe-west1,_ARTIFACT_REGISTRY=credovo-services,_SERVICE_NAME=orchestration-service" `
  --service-account="github-actions@credovo-eu-apps-nonprod.iam.gserviceaccount.com" `
  --project=credovo-eu-apps-nonprod

# Create trigger for kyc-kyb-service
gcloud builds triggers create github `
  --name="deploy-kyc-kyb-service" `
  --region=europe-west1 `
  --repo-name="credovo-platform" `
  --repo-owner="AmanorsElliot" `
  --branch-pattern="^main$" `
  --build-config="services/kyc-kyb-service/cloudbuild.yaml" `
  --substitutions="_REGION=europe-west1,_ARTIFACT_REGISTRY=credovo-services,_SERVICE_NAME=kyc-kyb-service" `
  --service-account="github-actions@credovo-eu-apps-nonprod.iam.gserviceaccount.com" `
  --project=credovo-eu-apps-nonprod

# Create trigger for connector-service
gcloud builds triggers create github `
  --name="deploy-connector-service" `
  --region=europe-west1 `
  --repo-name="credovo-platform" `
  --repo-owner="AmanorsElliot" `
  --branch-pattern="^main$" `
  --build-config="services/connector-service/cloudbuild.yaml" `
  --substitutions="_REGION=europe-west1,_ARTIFACT_REGISTRY=credovo-services,_SERVICE_NAME=connector-service" `
  --service-account="github-actions@credovo-eu-apps-nonprod.iam.gserviceaccount.com" `
  --project=credovo-eu-apps-nonprod
```

## Step 3: Update cloudbuild.yaml Files

The existing `cloudbuild.yaml` files should work, but we need to ensure they use the correct substitutions:

- `_REGION`: `europe-west1`
- `_ARTIFACT_REGISTRY`: `credovo-services`
- `_SERVICE_NAME`: Service name (orchestration-service, kyc-kyb-service, connector-service)
- `SHORT_SHA`: Automatically provided by Cloud Build (first 7 chars of commit SHA)

## Step 4: Test the Setup

1. Make a small change to any service
2. Push to `main` branch
3. Go to: https://console.cloud.google.com/cloud-build/builds?project=credovo-eu-apps-nonprod
4. Watch the build execute automatically

## Step 5: Disable GitHub Actions (Optional)

Once Cloud Build triggers are working, you can disable the GitHub Actions workflow:

1. Go to: https://github.com/AmanorsElliot/credovo-platform/settings/actions
2. Disable workflows or keep them as backup

## Troubleshooting

### Connection Status Shows "Configuration incomplete"

- Complete the OAuth authorization in the GCP Console
- Make sure you authorized the correct GitHub account
- Check that the repository is accessible

### Builds Not Triggering

- Verify the branch pattern matches your branch name
- Check that the `cloudbuild.yaml` file path is correct
- Ensure the service account has necessary permissions

### Permission Errors

- Make sure the service account has:
  - `roles/run.admin` (to deploy to Cloud Run)
  - `roles/artifactregistry.writer` (to push images)
  - `roles/iam.serviceAccountUser` (to use service accounts)

## Next Steps

After setting up triggers:
1. ✅ Test with a small commit
2. ✅ Verify builds trigger automatically
3. ✅ Check that services deploy correctly
4. ✅ Monitor build logs for any issues

