# IAM Analysis for credovo-eu-apps-nonprod

## Current IAM Roles

### Groups with Permissions

**credovo-platform-admins@credovo.com** has:
- `roles/billing.projectManager`
- `roles/resourcemanager.projectIamAdmin`
- `roles/serviceusage.serviceUsageAdmin`

**credovo-product-devs@credovo.com** has:
- `roles/cloudtrace.viewer`
- `roles/errorreporting.viewer`
- `roles/logging.viewer`
- `roles/monitoring.viewer`

**credovo-risk-devs@credovo.com** has:
- `roles/cloudtrace.viewer`
- `roles/errorreporting.viewer`
- `roles/logging.viewer`
- `roles/monitoring.viewer`

### Service Accounts

**cicd-deployer@credovo-eu-apps-nonprod.iam.gserviceaccount.com** has:
- `roles/artifactregistry.writer`
- `roles/iam.serviceAccountUser`
- `roles/run.admin`

## Missing Permissions

### For Manual Bucket Creation
- ❌ `roles/storage.admin` - Not assigned to any user/group
- ❌ `roles/storage.objectAdmin` - Not assigned to any user/group
- ❌ Direct storage permissions

### For Secret Manager
- ❌ `roles/secretmanager.admin` - Not assigned
- ❌ `roles/secretmanager.secretAccessor` - Not assigned (for users)

## Organization Policies

1. **gcp.restrictServiceUsage** - Restricts which GCP services can be used
   - **BLOCKING**: Storage, Secret Manager, Pub/Sub, Cloud Tasks, VPC Access, Artifact Registry
   - This affects BOTH manual operations AND Terraform
   - The policy blocks service usage at the project level, regardless of IAM permissions

2. **storage.uniformBucketLevelAccess** - Enforces uniform bucket-level access

## Solution

### ❌ Option 1: Use Terraform (FAILED)
Terraform deployment failed because organization policies block service usage regardless of IAM permissions.

### ✅ Option 2: Request Policy Exemptions (REQUIRED)
The organization admin must add these services to the allowed list:
- `storage.googleapis.com`
- `secretmanager.googleapis.com`
- `pubsub.googleapis.com`
- `cloudtasks.googleapis.com`
- `vpcaccess.googleapis.com`
- `artifactregistry.googleapis.com`

### ✅ Option 3: Request IAM Permissions (REQUIRED)
Ask your GCP admin to grant:
- `roles/iam.serviceAccountAdmin` (for creating service accounts)
- `roles/logging.configWriter` (for creating logging metrics)
- `roles/monitoring.admin` (for creating dashboards and alerts)

## Next Steps

1. **Contact GCP Admin** - See `docs/PERMISSIONS_REQUIRED.md` for detailed request
2. **Request policy exemptions** for the 6 blocked services
3. **Request IAM roles** for service account and monitoring management
4. **Re-run Terraform** after permissions are granted

