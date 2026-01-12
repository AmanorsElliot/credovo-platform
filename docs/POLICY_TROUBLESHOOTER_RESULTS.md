# Policy Troubleshooter Results

## Test Date
January 11, 2026

## Test 1: Policy Troubleshooter

### Configuration
- **Principal**: `elliot@amanors.com`
- **Resource**: `projects/858440156644/locations/europe-west1/services/proxy-service`
- **Permission**: `run.services.setIamPolicy`

### Results
- **Outcome**: Unknown (due to insufficient permissions to view all policy types)
- **Allow Policy**: ✅ Access is granted by at least one IAM allow policy
- **Deny Policy**: ⚠️ Cannot view (insufficient permissions)
- **Principal Access Boundary**: ⚠️ Cannot view (insufficient permissions)

### Analysis
The troubleshooter showed that the user has permission to set IAM policies, but the "Unknown" outcome suggests that organization-level deny policies may be blocking the operation. The inability to view deny policies and principal access boundary policies prevents a definitive answer.

## Test 2: Direct IAM Policy Binding Test

### Command Executed
```powershell
gcloud run services add-iam-policy-binding proxy-service `
    --region=europe-west1 `
    --member="allUsers" `
    --role=roles/run.invoker `
    --project=credovo-eu-apps-nonprod
```

### Results
❌ **FAILED**

**Error Message:**
```
ERROR: (gcloud.run.services.add-iam-policy-binding) FAILED_PRECONDITION: 
One or more users named in the policy do not belong to a permitted customer, 
perhaps due to an organization policy.
```

### Analysis
This confirms that the `iam.allowedPolicyMemberDomains` organization policy is blocking the addition of `allUsers` to the IAM policy. The policy restricts IAM bindings to members from specific domains/customers, and `allUsers` does not meet this requirement.

## Conclusion

The organization policy `iam.allowedPolicyMemberDomains` is definitively blocking public access (`allUsers`) to the Cloud Run service. This policy cannot be bypassed through:
- Direct IAM policy binding (tested and failed)
- Console UI (no exemptions tab available)
- Policy modification (policy only accepts domains/customer IDs, not `allUsers`)

## Next Steps

1. **Contact GCP Support** to request an exemption for the proxy service
2. **Provide this documentation** as evidence of the policy blocking access
3. **Request exemption** for:
   - Resource: `projects/858440156644/locations/europe-west1/services/proxy-service`
   - Constraint: `iam.allowedPolicyMemberDomains`
   - Justification: Proxy service needs public access to receive requests from Supabase Edge Functions

## Support Request Template

When contacting GCP Support, include:

```
Subject: Organization Policy Exemption Request for Cloud Run Service

We need to exempt our Cloud Run service from the iam.allowedPolicyMemberDomains 
organization policy to allow public (allUsers) access.

Service Details:
- Project: credovo-eu-apps-nonprod (858440156644)
- Service: proxy-service
- Region: europe-west1
- Resource: projects/858440156644/locations/europe-west1/services/proxy-service

Error Message:
FAILED_PRECONDITION: One or more users named in the policy do not belong to a 
permitted customer, perhaps due to an organization policy.

Justification:
The proxy service acts as an intermediary between Supabase Edge Functions 
(which cannot authenticate with Google Cloud IAM) and our internal Cloud Run 
services. It requires public access to receive requests from the Supabase 
platform.

We have attempted:
1. Direct IAM policy binding (failed with above error)
2. Console-based exemption (no exemptions tab available for this constraint)
3. Policy modification (policy only accepts domains, not allUsers)

Please provide guidance on how to proceed with this exemption request.
```
