# Policy Violation Details - EU Data Boundary Compliance

## Violation Summary

**Violation ID**: `95356f73-11c2-47e0-9041-9083f2bcf835`  
**Time**: January 12, 2026 at 6:50:36 AM UTC  
**Status**: Unresolved  
**Folder**: `eu-gdpr` (folder ID: `351913445774`, display name: `non-prod`)

## Policy Comparison

### Folder-Level Policy (eu-gdpr) - EU Data Boundary Compliant
The folder policy allows:
- ✅ `bigquery.googleapis.com`
- ✅ `storage.googleapis.com`
- ✅ `secretmanager.googleapis.com`
- ✅ `pubsub.googleapis.com`
- ✅ `cloudtasks.googleapis.com`
- ✅ `vpcaccess.googleapis.com`
- ✅ `artifactregistry.googleapis.com`
- ✅ `cloudbuild.googleapis.com`

### Project-Level Policy (credovo-eu-apps-nonprod) - Non-Compliant
The project policy allows all of the above PLUS:
- ⚠️ `run.googleapis.com` - **NOT in folder policy** (but needed for Cloud Run)
- ⚠️ `compute.sslCertificates.create` - **NOT in folder policy** (added for Load Balancer, now removed)
- ⚠️ `apigateway.googleapis.com` - **NOT in folder policy** (added for API Gateway)

## Root Cause

The project-level policy has been modified to allow services that are **not allowed** at the folder level, causing the EU Data Boundary compliance violation.

## Services Causing Violation

1. **`compute.sslCertificates.create`** 
   - Added for HTTPS Load Balancer
   - **Status**: Load Balancer removed, can be removed from project policy
   - **Action**: Remove from project policy

2. **`apigateway.googleapis.com`**
   - Added for API Gateway deployment
   - **Status**: Needed for API Gateway solution
   - **Action**: Need to decide - add to folder policy OR use alternative solution

3. **`run.googleapis.com`**
   - Required for Cloud Run services
   - **Status**: Critical for all services
   - **Action**: Should be in folder policy (may be missing by mistake)

## Recommended Actions

### Immediate: Remove Load Balancer Service
```powershell
# Remove compute.sslCertificates.create from project policy
# This service is no longer needed since Load Balancer is removed
```

### Short-term: Fix run.googleapis.com
```powershell
# Add run.googleapis.com to folder-level policy
# This is required for Cloud Run services and should be allowed
```

### Decision Required: API Gateway
Two options:

**Option A: Add API Gateway to Folder Policy**
- Request `apigateway.googleapis.com` be added to folder-level policy
- Maintains EU Data Boundary compliance
- Allows API Gateway deployment

**Option B: Use Organization Policy Exemption**
- Request exemption for `iam.allowedPolicyMemberDomains` 
- Allow `allUsers` on proxy service
- Use proxy service directly (no API Gateway needed)
- Simpler, avoids API Gateway complexity

## Impact Assessment

- **Current**: Project is non-compliant with EU Data Boundary
- **After removing `compute.sslCertificates.create`**: Still non-compliant (due to API Gateway)
- **After adding `run.googleapis.com` to folder**: Still non-compliant (due to API Gateway)
- **After resolving API Gateway**: Should be compliant

## Next Steps

1. ✅ **Remove `compute.sslCertificates.create`** from project policy (Load Balancer removed)
2. ⚠️ **Add `run.googleapis.com`** to folder-level policy (if missing)
3. 🤔 **Decide on API Gateway approach**:
   - Add to folder policy (maintains compliance)
   - OR use organization policy exemption (simpler, no API Gateway)
