# Platform Permissions and Constraints

## Overview

This document explains all organization policies, region constraints, and permission blocks that affect the Credovo platform, including how they impact service account permissions and public access.

## Organization Policies

### 1. `gcp.restrictServiceUsage` - Service Usage Restrictions

**Purpose**: Restricts which Google Cloud services can be used in the project.

**Policy Hierarchy**:
- **Organization Level**: Base policy (if exists)
- **Folder Level** (`eu-gdpr`): 8 services allowed
- **Project Level** (`credovo-eu-apps-nonprod`): **OVERRIDE** parent, 10 services allowed

**Current Project Policy** (Override Mode):
```json
{
  "constraint": "constraints/gcp.restrictServiceUsage",
  "listPolicy": {
    "allowedValues": [
      "storage.googleapis.com",
      "secretmanager.googleapis.com",
      "pubsub.googleapis.com",
      "cloudtasks.googleapis.com",
      "vpcaccess.googleapis.com",
      "artifactregistry.googleapis.com",
      "run.googleapis.com",              // ⚠️ CRITICAL - Not in folder policy
      "bigquery.googleapis.com",
      "cloudbuild.googleapis.com",
      "apigateway.googleapis.com"         // ⚠️ CRITICAL - Not in folder policy
    ]
  }
}
```

**Impact**:
- ✅ **Services in the list**: Can be enabled and used
- ❌ **Services NOT in the list**: Cannot be enabled or used
- ⚠️ **Project overrides folder**: Must maintain project policy separately
- ⚠️ **Critical services missing from folder**: `run.googleapis.com` and `apigateway.googleapis.com` are only in project policy

**How to Update**:
```powershell
# Edit infrastructure/terraform/org-policy-exemption.json
# Add/remove services from allowedValues array

# Apply the policy
gcloud resource-manager org-policies set-policy infrastructure/terraform/org-policy-exemption.json --project=credovo-eu-apps-nonprod
```

**File Location**: `infrastructure/terraform/org-policy-exemption.json`

---

### 2. `iam.allowedPolicyMemberDomains` - Domain-Restricted Sharing

**Purpose**: Restricts IAM policy members to specific domains or customer IDs. **This blocks `allUsers` (public access)**.

**Current Status**: **ACTIVE** - Blocks public access to Cloud Run services

**Impact on Service Accounts**:
- ✅ **Service accounts work fine**: Can be granted permissions normally
- ✅ **User accounts from allowed domains**: Can be granted permissions
- ❌ **`allUsers` is BLOCKED**: Cannot be added to IAM policies
- ❌ **Public access is BLOCKED**: Cloud Run services cannot be made publicly accessible

**Error When Attempting Public Access**:
```
ERROR: (gcloud.run.services.add-iam-policy-binding) FAILED_PRECONDITION: 
One or more users named in the policy do not belong to a permitted customer, 
perhaps due to an organization policy.
```

**Affected Resources**:
- ❌ **Proxy Service**: Cannot be made public (needed for Supabase Edge Functions)
- ❌ **Any Cloud Run service**: Cannot grant `allUsers` access

**Workaround**: Request organization policy exemption (see below)

**Exemption Request Template**:
```
Subject: Organization Policy Exemption Request for Cloud Run Service

Constraint: iam.allowedPolicyMemberDomains
Resource: projects/858440156644/locations/europe-west1/services/proxy-service
Service: proxy-service

Justification:
- Required for Supabase Edge Function integration
- Edge Functions run in Supabase (external to GCP) and cannot use GCP service accounts
- The proxy service only forwards authenticated requests (requires Supabase JWT token)
- Application layer enforces authentication (Supabase JWT validation)
- No alternative architecture that maintains security boundaries
```

---

### 3. `gcp.resourceLocations` - Resource Location Restrictions

**Purpose**: Restricts where resources can be created (regions/zones).

**Current Status**: **ACTIVE** - Restricts resources to specific regions

**Allowed Regions**:
- ✅ `europe-west1` (Belgium) - **Primary region for all services**
- ❌ Other regions may be blocked

**Impact**:
- ✅ **Deployments in `europe-west1`**: Work fine
- ❌ **Deployments in other regions**: May be blocked
- ⚠️ **All services must use `europe-west1`**: Cloud Run, API Gateway, etc.

**How to Check**:
```powershell
gcloud resource-manager org-policies describe gcp.resourceLocations `
  --project=credovo-eu-apps-nonprod `
  --format="yaml"
```

**Exemption for Proxy Service** (if needed):
- Resource: `projects/858440156644/locations/europe-west1/services/proxy-service`
- Constraint: `constraints/gcp.resourceLocations`
- Reason: Required for Supabase Edge Function integration

---

## Region Constraints

### Primary Region: `europe-west1` (Belgium)

**All services must be deployed in `europe-west1`**:
- ✅ Cloud Run services
- ✅ API Gateway
- ✅ Artifact Registry
- ✅ VPC Connector
- ✅ Secret Manager

**Why**: Organization policy `gcp.resourceLocations` restricts resource creation to this region.

**Impact**:
- ✅ **Compliance**: GDPR-compliant region
- ✅ **Consistency**: All services in same region (low latency)
- ❌ **No multi-region**: Cannot deploy to other regions for redundancy

---

## Service Account Permissions

### Service Accounts Work Normally

**Service accounts are NOT affected by `iam.allowedPolicyMemberDomains`**:
- ✅ Can be created
- ✅ Can be granted IAM roles
- ✅ Can authenticate to other services
- ✅ Can be used by Cloud Run services

### Current Service Accounts

All services use dedicated service accounts:
- `orchestration-service@credovo-eu-apps-nonprod.iam.gserviceaccount.com`
- `connector-service@credovo-eu-apps-nonprod.iam.gserviceaccount.com`
- `proxy-service@credovo-eu-apps-nonprod.iam.gserviceaccount.com`
- `kyc-kyb-service@credovo-eu-apps-nonprod.iam.gserviceaccount.com`
- `open-banking-service@credovo-eu-apps-nonprod.iam.gserviceaccount.com`

**Permissions Granted**:
- ✅ `roles/secretmanager.secretAccessor` - Access to secrets
- ✅ `roles/run.invoker` - Invoke other Cloud Run services
- ✅ Service-specific permissions as needed

---

## Public Access Blocks

### The Problem

**`iam.allowedPolicyMemberDomains` blocks `allUsers` access**:
- ❌ Cannot grant `allUsers` to Cloud Run services
- ❌ Cannot make services publicly accessible
- ❌ Edge Functions cannot authenticate with GCP (only have Supabase JWT)

### Why This Matters

**Supabase Edge Functions**:
- Run in Supabase infrastructure (external to GCP)
- Cannot use GCP service accounts
- Cannot get Google Identity Tokens
- Can only make HTTP requests with Supabase JWT tokens
- **Require publicly accessible endpoints**

**Current Architecture**:
```
Supabase Edge Function (external, Supabase JWT only)
  ↓
❌ Proxy Service (BLOCKED - cannot be made public)
  ↓
Orchestration Service (authenticated, validates Supabase JWT)
```

### Workarounds

1. **API Gateway** (Current Solution):
   - ✅ Publicly accessible (doesn't require `allUsers` on Cloud Run)
   - ✅ Works for POST/PUT/DELETE requests
   - ❌ **BUG**: Rejects all GET requests with 400 errors

2. **Organization Policy Exemption** (Recommended):
   - Request exemption for proxy service
   - Allows `allUsers` access to specific service
   - Requires GCP Support approval

3. **Alternative Architecture** (Not Recommended):
   - Make orchestration service public (security risk)
   - Use different authentication mechanism
   - Deploy Edge Functions in GCP (defeats purpose of Supabase)

---

## Policy Inheritance

### Current Configuration: Override Mode

**Project Policy**: Overrides parent folder policy (does NOT inherit)

**What This Means**:
- ✅ Project policy must explicitly list ALL allowed services
- ❌ Project policy does NOT automatically inherit from folder
- ⚠️ Any service not in project policy is BLOCKED, even if allowed at folder level

**Folder Policy** (`eu-gdpr`):
- 8 services allowed
- Missing: `run.googleapis.com` and `apigateway.googleapis.com`

**Project Policy** (`credovo-eu-apps-nonprod`):
- 10 services allowed
- Includes: `run.googleapis.com` and `apigateway.googleapis.com`

**Risk**: If project policy is reset or deleted, Cloud Run and API Gateway would stop working.

### Switching to Inherit Mode

**Requirements Before Switching**:
1. ✅ Add `run.googleapis.com` to folder policy (CRITICAL)
2. ✅ Add `apigateway.googleapis.com` to folder policy
3. ✅ Ensure all other services are in folder policy

**Current Recommendation**: **Keep Override Mode** until folder policy includes all required services.

---

## Summary of Blocks

### ✅ What Works

- ✅ Service accounts and IAM roles
- ✅ Service-to-service authentication
- ✅ Deployments in `europe-west1`
- ✅ Services listed in `gcp.restrictServiceUsage`
- ✅ POST/PUT/DELETE requests through API Gateway

### ❌ What's Blocked

- ❌ Public access (`allUsers`) to Cloud Run services
- ❌ GET requests through API Gateway (bug, not policy)
- ❌ Deployments outside `europe-west1`
- ❌ Services not in `gcp.restrictServiceUsage` list
- ❌ Direct Edge Function → Cloud Run calls (needs public access)

### ⚠️ Current Limitations

1. **GET Requests**: API Gateway bug rejects all GET requests
2. **Public Access**: Organization policy blocks `allUsers`
3. **Policy Inheritance**: Project must maintain separate policy
4. **Region Flexibility**: Restricted to `europe-west1` only

---

## Required Actions

### Immediate

1. **Request API Gateway GET bug fix** from Google Cloud Support
2. **Request organization policy exemption** for proxy service:
   - Constraint: `iam.allowedPolicyMemberDomains`
   - Resource: `projects/858440156644/locations/europe-west1/services/proxy-service`
   - Justification: Required for Supabase Edge Function integration

### Long-term

1. **Add `run.googleapis.com` to folder policy** (for consistency)
2. **Add `apigateway.googleapis.com` to folder policy** (for consistency)
3. **Consider switching to inherit mode** (after folder policy is updated)
4. **Monitor API Gateway** for GET request fix

---

## Verification Commands

### Check Service Usage Policy
```powershell
gcloud resource-manager org-policies describe gcp.restrictServiceUsage `
  --project=credovo-eu-apps-nonprod `
  --format="yaml"
```

### Check Resource Locations Policy
```powershell
gcloud resource-manager org-policies describe gcp.resourceLocations `
  --project=credovo-eu-apps-nonprod `
  --format="yaml"
```

### Check IAM Allowed Domains Policy
```powershell
gcloud resource-manager org-policies describe iam.allowedPolicyMemberDomains `
  --project=credovo-eu-apps-nonprod `
  --format="yaml"
```

### Test Public Access (Will Fail)
```powershell
gcloud run services add-iam-policy-binding proxy-service `
  --region=europe-west1 `
  --member="allUsers" `
  --role=roles/run.invoker `
  --project=credovo-eu-apps-nonprod
```

---

## Related Documentation

- `docs/POLICY_CONFIGURATION.md` - Detailed policy configuration
- `docs/POLICY_INHERITANCE_ANALYSIS.md` - Policy inheritance analysis
- `docs/POLICY_TROUBLESHOOTER_RESULTS.md` - Policy troubleshooter results
- `docs/PROXY_SERVICE_403_FIX.md` - Proxy service 403 error fix
- `docs/API_GATEWAY_GET_400_CONFIRMED.md` - API Gateway GET request bug
- `infrastructure/terraform/org-policy-exemption.json` - Project policy definition
