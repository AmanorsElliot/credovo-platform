# Final Solution: Making Proxy Service Publicly Accessible

## Current Situation

- ✅ Proxy service is deployed: `https://proxy-service-saz24fo3sa-ew.a.run.app`
- ✅ Service account permissions are correct
- ❌ **Blocked by organization policy**: `iam.allowedPolicyMemberDomains` prevents `allUsers` access
- ❌ Exemptions not available in console for this constraint
- ❌ `allUsers` cannot be added as a policy value (only domains/customer IDs accepted)

## Recommended Solution: Contact GCP Support

Since you're the project owner, the best approach is to **contact GCP Support** to request an exemption:

### Support Request Details

**Subject**: Request Organization Policy Exemption for Cloud Run Service

**Details**:
- **Constraint**: `iam.allowedPolicyMemberDomains`
- **Resource**: `projects/858440156644/locations/europe-west1/services/proxy-service`
- **Service**: `proxy-service`
- **Justification**: 
  - Required for Supabase Edge Function integration
  - Edge Functions run in Supabase (external to GCP) and cannot use GCP service accounts
  - The proxy service only forwards authenticated requests (requires Supabase JWT token)
  - Application layer enforces authentication (Supabase JWT validation)
  - No alternative architecture that maintains security boundaries

**Security Justification**:
- Proxy service is a pass-through - doesn't store or process data
- All requests must include valid Supabase JWT token
- Orchestration service validates JWT before processing any requests
- All requests are logged for audit purposes

## Alternative: Temporary Workaround

If you need immediate access while waiting for support, you could temporarily:

1. **Make orchestration service public** (not recommended for production):
   ```powershell
   # This will also fail due to the same policy, but worth trying
   gcloud run services add-iam-policy-binding orchestration-service `
     --region=europe-west1 `
     --member="allUsers" `
     --role="roles/run.invoker" `
     --project=credovo-eu-apps-nonprod `
     --condition=None
   ```

2. **Update Edge Function** to call orchestration service directly (bypass proxy)

⚠️ **Warning**: This bypasses the proxy service architecture and may violate regulatory requirements.

## After Support Grants Exemption

Once the exemption is granted:

```powershell
# Grant public access to proxy service
gcloud run services add-iam-policy-binding proxy-service `
  --region=europe-west1 `
  --member="allUsers" `
  --role="roles/run.invoker" `
  --project=credovo-eu-apps-nonprod `
  --condition=None

# Verify access
$proxyUrl = "https://proxy-service-saz24fo3sa-ew.a.run.app"
Invoke-RestMethod -Uri "$proxyUrl/health"
```

Then update your Edge Function to use `PROXY_SERVICE_URL=https://proxy-service-saz24fo3sa-ew.a.run.app`.

## How to Contact GCP Support

1. Go to [GCP Support](https://console.cloud.google.com/support)
2. Click "Create Case" or "Contact Support"
3. Select "Technical" issue type
4. Provide the details above
5. Request exemption for the proxy service

## Summary

The organization policy `iam.allowedPolicyMemberDomains` is correctly configured for security, but it blocks `allUsers` which is required for the Supabase Edge Function integration. Since exemptions aren't available in the console and the API approach is complex, **contacting GCP Support is the recommended path forward**.
