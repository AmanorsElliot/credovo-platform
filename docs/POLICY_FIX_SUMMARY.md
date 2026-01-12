# Policy Violation Fix Summary

## Issue Identified

The `eu-gdpr` folder had a policy violation because the project-level policy allowed services not permitted at the folder level:
- ❌ `compute.sslCertificates.create` (added for Load Balancer - now removed)
- ❌ `apigateway.googleapis.com` (added for API Gateway - also removed)

## Actions Taken

### ✅ Removed `compute.sslCertificates.create`
- **Reason**: Load Balancer has been removed, this service is no longer needed
- **Status**: Removed from project policy
- **Impact**: No longer causing violation

### ⚠️ Removed `apigateway.googleapis.com`
- **Reason**: Not allowed at folder level, causing EU Data Boundary violation
- **Status**: Removed from project policy
- **Impact**: **API Gateway cannot be deployed** with current policy

## Current Project Policy

The project policy now matches the folder-level allowed services:
- ✅ `storage.googleapis.com`
- ✅ `secretmanager.googleapis.com`
- ✅ `pubsub.googleapis.com`
- ✅ `cloudtasks.googleapis.com`
- ✅ `vpcaccess.googleapis.com`
- ✅ `artifactregistry.googleapis.com`
- ✅ `run.googleapis.com`
- ✅ `bigquery.googleapis.com`
- ✅ `cloudbuild.googleapis.com`

## Problem: API Gateway Not Available

Since `apigateway.googleapis.com` is not allowed at the folder level, we cannot deploy API Gateway without violating EU Data Boundary compliance.

## Solutions

### Option 1: Request Folder-Level Exception for API Gateway
**Pros:**
- Maintains EU Data Boundary compliance
- Allows API Gateway deployment

**Cons:**
- Requires admin approval
- May take time to process

**Action:**
Request that `apigateway.googleapis.com` be added to the `eu-gdpr` folder policy.

### Option 2: Use Organization Policy Exemption (Recommended)
**Pros:**
- Simpler solution
- No API Gateway needed
- Direct access to proxy service

**Cons:**
- Requires exemption for `iam.allowedPolicyMemberDomains`
- Proxy service becomes publicly accessible

**Action:**
Request organization policy exemption to allow `allUsers` on the proxy service, then use it directly without API Gateway.

## Recommendation

**Use Option 2 (Organization Policy Exemption)** because:
1. Simpler architecture (no API Gateway complexity)
2. Lower cost (no API Gateway fees)
3. Direct connection (proxy service → orchestration service)
4. Faster to implement (one exemption request vs. folder policy change)

## Next Steps

1. ✅ **Policy violation partially resolved** (removed Load Balancer service)
2. ⏭️ **Decide on approach**: API Gateway exception OR organization policy exemption
3. ⏭️ **If API Gateway**: Request folder-level policy change
4. ⏭️ **If exemption**: Request `iam.allowedPolicyMemberDomains` exemption for proxy service
