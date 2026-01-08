# Organization-Level Permissions Analysis

## Organization Information

- **Organization ID**: `477641698806`
- **Organization Name**: `amanors.com`
- **Project**: `credovo-eu-apps-nonprod`
- **Parent Folder**: `351913445774`

## Key Permissions Needed

For Workload Identity and Service Account Key management, these roles are required:

### Organization Level
- `roles/orgpolicy.policyAdmin` - Organization Policy Administrator
- `roles/iam.workloadIdentityPoolAdmin` - Workload Identity Pool Admin
- `roles/resourcemanager.organizationAdmin` - Organization Admin

### Project Level
- `roles/iam.serviceAccountKeyAdmin` - Service Account Key Admin
- `roles/iam.serviceAccountAdmin` - Service Account Admin (you have this)
- `roles/iam.workloadIdentityPoolAdmin` - Workload Identity Pool Admin

## Organization-Level Permissions

### Key Finding: You Have Organization Admin!

**`elliot@amanors.com`** has:
- ✅ `roles/resourcemanager.organizationAdmin` - **Organization Administrator**
- ✅ `roles/assuredworkloads.admin` - Assured Workloads Admin
- ✅ `roles/billing.creator` - Billing Creator

**This means you should be able to create Workload Identity Pools!**

### Organization Structure

- **Organization**: `477641698806` (amanors.com)
- **Folder**: `314859600086` (credovo)
- **Sub-Folder**: `351913445774` (parent of credovo-eu-apps-nonprod)
- **Project**: `credovo-eu-apps-nonprod`

### Folder-Level Permissions

**Folder `314859600086` (credovo):**
- `roles/resourcemanager.folderAdmin` - `credovo-eu-data-admins@credovo.com`
- `roles/resourcemanager.folderViewer` - `credovo-auditors@credovo.com`
- `roles/resourcemanager.folderViewer` - `credovo-platform-admins@credovo.com`

**Folder `351913445774` (parent folder):**
- `roles/resourcemanager.folderAdmin` - `credovo-eu-data-admins@credovo.com`
- `roles/resourcemanager.folderViewer` - `credovo-auditors@credovo.com`
- `roles/resourcemanager.folderViewer` - `credovo-platform-admins@credovo.com`

## Current Project-Level Permissions

Based on analysis, the following groups/users have project-level permissions:

### `credovo-platform-admins@credovo.com` Group
- ✅ `roles/iam.serviceAccountAdmin`
- ✅ `roles/iam.serviceAccountUser`
- ✅ `roles/resourcemanager.projectIamAdmin`
- ✅ `roles/run.admin`
- ✅ `roles/artifactregistry.admin`
- ✅ `roles/secretmanager.admin`
- ✅ `roles/storage.admin`
- ✅ `roles/bigquery.dataOwner`
- ✅ `roles/monitoring.admin`
- ✅ `roles/logging.configWriter`
- ✅ `roles/pubsub.admin`
- ✅ `roles/cloudtasks.admin`
- ✅ `roles/vpcaccess.admin`
- ✅ `roles/billing.projectManager`
- ✅ `roles/compute.networkAdmin`
- ✅ `roles/serviceusage.serviceUsageAdmin`

**Note**: This group has project-level admin permissions but may not have organization-level permissions needed for Workload Identity Pools.

## Missing Permissions

To set up Workload Identity, you need someone with:

1. **Organization Policy Admin** (`roles/orgpolicy.policyAdmin`)
   - Can modify organization policies
   - Can create Workload Identity Pools at org level

2. **Organization Admin** (`roles/resourcemanager.organizationAdmin`)
   - Full organization-level access
   - Can create Workload Identity resources

3. **Workload Identity Pool Admin** (`roles/iam.workloadIdentityPoolAdmin`)
   - Can create and manage Workload Identity Pools
   - Can create providers

## Permission Summary

### Organization Level (477641698806 - amanors.com)

| Role | Members |
|------|---------|
| `roles/resourcemanager.organizationAdmin` | `elliot@amanors.com` ✅ |
| `roles/assuredworkloads.admin` | `elliot@amanors.com` |
| `roles/billing.creator` | `domain:amanors.com` |
| `roles/resourcemanager.projectCreator` | `domain:amanors.com` |

### Folder Level (314859600086 - credovo)

| Role | Members |
|------|---------|
| `roles/resourcemanager.folderAdmin` | `credovo-org-admins@credovo.com` |
| `roles/resourcemanager.folderViewer` | `credovo-auditors@credovo.com` |

### Folder Level (351913445774 - parent folder)

| Role | Members |
|------|---------|
| `roles/resourcemanager.folderAdmin` | `credovo-eu-data-admins@credovo.com` |
| `roles/resourcemanager.folderViewer` | `credovo-auditors@credovo.com`, `credovo-platform-admins@credovo.com` |

### Project Level (credovo-eu-apps-nonprod)

**Key Groups:**
- `credovo-platform-admins@credovo.com` - Has most project admin roles
- `elliot@amanors.com` - Check individual permissions below

## How to Check Permissions

Run these commands to see who has what permissions:

```powershell
# Check organization IAM
gcloud organizations get-iam-policy 477641698806 --format="table(bindings.role,bindings.members)"

# Check project IAM for specific user
gcloud projects get-iam-policy credovo-eu-apps-nonprod --flatten="bindings[].members" --filter="bindings.members:elliot@amanors.com" --format="table(bindings.role)"

# Check folder-level permissions
gcloud resource-manager folders get-iam-policy 351913445774 --format="table(bindings.role,bindings.members)"
```

## Workload Identity Pool Creation Issue

### The Problem

Even though you have `roles/resourcemanager.organizationAdmin` at the organization level, you're getting permission denied when trying to create Workload Identity Pools at the project level.

### Why This Happens

Workload Identity Pools are created at the **project level**, but require:
- `roles/iam.workloadIdentityPoolAdmin` at the project level, OR
- Organization admin permissions that grant project-level IAM permissions

### Solution Options

1. **Grant the specific role** at project level:
   ```powershell
   gcloud projects add-iam-policy-binding credovo-eu-apps-nonprod \
     --member="user:elliot@amanors.com" \
     --role="roles/iam.workloadIdentityPoolAdmin"
   ```

2. **Use a service account with the role**:
   - Create a service account with `roles/iam.workloadIdentityPoolAdmin`
   - Impersonate that service account to create the pool

3. **Request from another admin** who has the role

4. **Use Cloud Build Triggers** (alternative that doesn't need Workload Identity)

### Alternative Approaches

1. **Request specific role**: Ask for `roles/iam.workloadIdentityPoolAdmin` to be granted
2. **Use Cloud Build Triggers**: Don't require Workload Identity
3. **Manual deployment**: For now, deploy manually until Workload Identity is set up

## Next Steps

1. Run the organization IAM check commands above
2. Identify who has organization-level permissions
3. Request Workload Identity setup from that person
4. Document the setup process for future reference

