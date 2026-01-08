# Workload Identity Provider - Audiences Configuration

## What to Select

✅ **Keep "Default audience" selected**

This is the correct setting for GitHub Actions. The default audience will be:
```
https://iam.googleapis.com/projects/858440156644/locations/global/workloadIdentityPools/github-actions/providers/github-provider
```

GitHub Actions will automatically use this audience when requesting OIDC tokens.

## Why Default Audience?

- GitHub Actions OIDC tokens automatically include the correct audience
- No need to manually specify allowed audiences
- Simpler configuration

## Next Steps

After clicking "Continue", you'll configure:
1. **Attribute Mapping** - Map GitHub claims to Google attributes
2. **Attribute Condition** - Restrict to your repository (optional but recommended)

## Attribute Mapping to Configure

- **Google attribute**: `google.subject`
- **Attribute value**: `assertion.sub`

This maps GitHub's subject claim to Google's subject.

## Attribute Condition (Recommended)

Add this condition to restrict access to your repository:
```
assertion.repository == "AmanorsElliot/credovo-platform"
```

This ensures only workflows from your specific repository can authenticate.

