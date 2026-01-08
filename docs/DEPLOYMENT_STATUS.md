# Terraform Deployment Status

## ✅ IAM Permissions - FIXED

Successfully granted the following roles to `credovo-platform-admins@credovo.com`:
- ✅ `roles/iam.serviceAccountAdmin` - Can create service accounts
- ✅ `roles/logging.configWriter` - Can create logging metrics
- ✅ `roles/monitoring.admin` - Can create dashboards and alerts
- ✅ `roles/storage.admin` - Can manage storage (when org policy allows)
- ✅ `roles/secretmanager.admin` - Can manage secrets (when org policy allows)

## ❌ Organization Policy - BLOCKING

The `gcp.restrictServiceUsage` constraint is blocking the following services:

### Blocked Services
1. ❌ **Cloud Storage** (`storage.googleapis.com`)
   - Required for: Data lake buckets (raw, archive, regional)
   - Error: `Request is disallowed by organization's constraints/gcp.restrictServiceUsage`

2. ❌ **Secret Manager** (`secretmanager.googleapis.com`)
   - Required for: API keys, JWT secrets, Supabase URL
   - Error: `Request is disallowed by organization's constraints/gcp.restrictServiceUsage`

3. ❌ **Pub/Sub** (`pubsub.googleapis.com`)
   - Required for: Event-driven messaging (KYC events, application events)
   - Error: `Request is disallowed by organization's constraints/gcp.restrictServiceUsage`

4. ❌ **Cloud Tasks** (`cloudtasks.googleapis.com`)
   - Required for: Async task processing (KYC queue)
   - Error: `Request is disallowed by organization's constraints/gcp.restrictServiceUsage`

5. ❌ **VPC Access** (`vpcaccess.googleapis.com`)
   - Required for: Private networking connector for Cloud Run
   - Error: `Request is disallowed by organization's constraints/gcp.restrictServiceUsage`

6. ❌ **Artifact Registry** (`artifactregistry.googleapis.com`)
   - Required for: Docker image repository
   - Error: `Request is disallowed by organization's constraints/gcp.restrictServiceUsage`

## ✅ Resources Created Successfully

Based on the deployment attempt, these resources were likely created:
- ✅ Service Accounts (all 9 microservice accounts)
- ✅ BigQuery Dataset
- ✅ Cloud Run Services (orchestration, KYC/KYB, connector)
- ✅ Monitoring Dashboards
- ✅ Logging Metrics
- ✅ Alert Policies

## Required Action

**Contact your GCP Organization Admin** to add these services to the allowed list for project `credovo-eu-apps-nonprod`:

```
storage.googleapis.com
secretmanager.googleapis.com
pubsub.googleapis.com
cloudtasks.googleapis.com
vpcaccess.googleapis.com
artifactregistry.googleapis.com
```

### How to Request

The organization admin needs to modify the `gcp.restrictServiceUsage` constraint to allow these services. This can be done via:

1. **GCP Console**: Organization Policies → `gcp.restrictServiceUsage` → Edit
2. **gcloud CLI**: 
   ```bash
   gcloud resource-manager org-policies set-policy \
     --project=credovo-eu-apps-nonprod \
     policy.yaml
   ```
3. **Terraform**: If they use Terraform for org policies

### Alternative: Use Different Project

If another project exists without these restrictions, we can deploy there instead.

## Next Steps

1. **Request org policy exemption** for the 6 blocked services
2. **Re-run Terraform** after exemption is granted
3. **Verify all resources** are created successfully
4. **Configure secrets** in Secret Manager
5. **Deploy services** to Cloud Run

