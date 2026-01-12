# Organization Policy Configuration

## Policy Source: Override Parent Policy

The project `credovo-eu-apps-nonprod` is configured to **override** the parent folder policy (`eu-gdpr`), not inherit it.

### What This Means

- ✅ **Project policy must explicitly list ALL allowed services**
- ❌ **Project policy does NOT automatically inherit from folder**
- ⚠️ **Any service not in project policy is BLOCKED**, even if allowed at folder level

### Current Folder Policy (eu-gdpr)

The folder-level policy allows:
- `artifactregistry.googleapis.com`
- `bigquery.googleapis.com`
- `cloudbuild.googleapis.com`
- `cloudtasks.googleapis.com`
- `pubsub.googleapis.com`
- `secretmanager.googleapis.com`
- `storage.googleapis.com`
- `vpcaccess.googleapis.com`
- `apigateway.googleapis.com` (recently added)

### Current Project Policy (credovo-eu-apps-nonprod)

The project policy (overriding folder) allows:
- `storage.googleapis.com`
- `secretmanager.googleapis.com`
- `pubsub.googleapis.com`
- `cloudtasks.googleapis.com`
- `vpcaccess.googleapis.com`
- `artifactregistry.googleapis.com`
- `run.googleapis.com` ⚠️ **Not in folder policy, but needed for Cloud Run**
- `bigquery.googleapis.com`
- `cloudbuild.googleapis.com`
- `apigateway.googleapis.com`

### Important Notes

1. **`run.googleapis.com` is in project policy but NOT in folder policy**
   - This is required for Cloud Run services
   - Should ideally be added to folder policy for consistency
   - Currently works because project overrides folder

2. **Project policy must be kept in sync with folder policy**
   - When folder policy changes, project policy must be updated
   - Missing services in project policy will be blocked

3. **Policy file location**: `infrastructure/terraform/org-policy-exemption.json`
   - This file defines the project-level policy
   - Must include ALL services that should be allowed

## Policy Management

To update the project policy:

```powershell
# Edit infrastructure/terraform/org-policy-exemption.json
# Add/remove services from allowedValues array

# Apply the policy
gcloud resource-manager org-policies set-policy infrastructure/terraform/org-policy-exemption.json --project=credovo-eu-apps-nonprod
```

## Recommendation

Consider changing to **inherit from parent** if:
- You want automatic inheritance of folder policy changes
- You only need to add a few project-specific services
- You want to reduce policy maintenance overhead

However, **override** is appropriate if:
- You need different services than the folder allows
- You want explicit control over project-level services
- You need to ensure specific services are always allowed
