# Required Permissions and Policy Exemptions

## Summary

The Terraform deployment failed due to **organization policy restrictions** and **missing IAM permissions**. The `gcp.restrictServiceUsage` constraint is blocking critical services, and the current user lacks permissions to create service accounts and monitoring resources.

## Organization Policy Restrictions

The following services are **blocked by organization policy** (`gcp.restrictServiceUsage`):

### Blocked Services
1. ❌ **Cloud Storage** (`storage.googleapis.com`) - Required for data lake buckets
2. ❌ **Secret Manager** (`secretmanager.googleapis.com`) - Required for API keys and secrets
3. ❌ **Pub/Sub** (`pubsub.googleapis.com`) - Required for event-driven messaging
4. ❌ **Cloud Tasks** (`cloudtasks.googleapis.com`) - Required for async task processing
5. ❌ **VPC Access** (`vpcaccess.googleapis.com`) - Required for private networking
6. ❌ **Artifact Registry** (`artifactregistry.googleapis.com`) - Required for Docker images

### Services That Worked
✅ Cloud Run (`run.googleapis.com`)
✅ BigQuery (`bigquery.googleapis.com`)
✅ Cloud Build (`cloudbuild.googleapis.com`)
✅ Monitoring (`monitoring.googleapis.com`)
✅ Logging (`logging.googleapis.com`)
✅ IAM (`iam.googleapis.com`)

## Missing IAM Permissions

The current user account lacks the following permissions:

### Service Account Management
- ❌ `iam.serviceAccounts.create` - Cannot create service accounts for microservices
- ❌ `iam.serviceAccounts.get` - May not be able to read service accounts

### Monitoring & Logging
- ❌ `logging.logMetrics.create` - Cannot create logging metrics
- ❌ `monitoring.alertPolicies.create` - Cannot create alert policies
- ❌ `monitoring.dashboards.create` - Cannot create monitoring dashboards

## Required Actions

### 1. Request Organization Policy Exemption

Contact your **GCP Organization Admin** to add the following services to the allowed list for project `credovo-eu-apps-nonprod`:

```
storage.googleapis.com
secretmanager.googleapis.com
pubsub.googleapis.com
cloudtasks.googleapis.com
vpcaccess.googleapis.com
artifactregistry.googleapis.com
```

**How to request:**
- The admin needs to modify the `gcp.restrictServiceUsage` constraint
- They can either:
  - Add these services to the allowed list for this project
  - Or grant an exception for this specific project

### 2. Request IAM Permissions

Request the following IAM roles for your user account or group (`credovo-product-devs@credovo.com` or `credovo-platform-admins@credovo.com`):

#### Option A: Grant Specific Roles (Recommended)
```bash
# Service Account Management
roles/iam.serviceAccountAdmin

# Monitoring & Logging
roles/logging.configWriter
roles/monitoring.admin
```

#### Option B: Grant Editor Role (Less Secure)
```bash
roles/editor  # Grants broad permissions
```

**Commands for GCP Admin:**
```bash
# For a group
gcloud projects add-iam-policy-binding credovo-eu-apps-nonprod \
  --member="group:credovo-product-devs@credovo.com" \
  --role="roles/iam.serviceAccountAdmin"

gcloud projects add-iam-policy-binding credovo-eu-apps-nonprod \
  --member="group:credovo-product-devs@credovo.com" \
  --role="roles/logging.configWriter"

gcloud projects add-iam-policy-binding credovo-eu-apps-nonprod \
  --member="group:credovo-product-devs@credovo.com" \
  --role="roles/monitoring.admin"
```

## Alternative Solutions

### Option 1: Use a Different Project
If another project exists without these restrictions, we can deploy there instead.

### Option 2: Manual Resource Creation
Have an admin create the resources manually, then import them into Terraform state.

### Option 3: Use Service Account with Permissions
If a service account exists with proper permissions, use it for Terraform:
```bash
gcloud auth activate-service-account --key-file=service-account-key.json
```

## Current Status

- ✅ **APIs Enabled**: Most APIs were successfully enabled
- ✅ **BigQuery Dataset**: Will be created once storage is available
- ❌ **Storage Buckets**: Blocked by org policy
- ❌ **Secret Manager**: Blocked by org policy
- ❌ **Service Accounts**: Missing IAM permissions
- ❌ **Pub/Sub Topics**: Blocked by org policy
- ❌ **Monitoring Resources**: Missing IAM permissions

## Next Steps

1. **Contact GCP Admin** with this document
2. **Request policy exemptions** for the 6 blocked services
3. **Request IAM roles** for service account and monitoring management
4. **Re-run Terraform** after permissions are granted

## Verification Commands

After permissions are granted, verify access:

```bash
# Check if you can create a test bucket
gsutil mb gs://test-bucket-$(date +%s)

# Check if you can create a test secret
echo "test" | gcloud secrets create test-secret --data-file=-

# Check if you can create a service account
gcloud iam service-accounts create test-sa --display-name="Test SA"

# Clean up test resources
gsutil rm -r gs://test-bucket-*
gcloud secrets delete test-secret
gcloud iam service-accounts delete test-sa@credovo-eu-apps-nonprod.iam.gserviceaccount.com
```

