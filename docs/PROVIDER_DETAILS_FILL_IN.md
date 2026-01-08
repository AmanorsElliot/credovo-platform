# Provider Details - What to Enter

## Required Fields

### 1. Provider name *
- **Enter**: `GitHub Provider`
- This is just a display name, can be anything descriptive

### 2. Provider ID *
- **Enter**: `github-provider`
- Must be lowercase, can use hyphens or underscores
- This will be used in the resource path

### 3. Issuer (URL) *
- **Enter**: `https://token.actions.githubusercontent.com`
- This is GitHub Actions' OIDC issuer URL
- Must start with `https://`

### 4. JWK file (JSON)
- **Leave empty** - Not needed
- GitHub's issuer is publicly accessible, so JWK file is optional

## After Saving

Once you save the provider, you'll need to:

1. **Configure Attribute Mapping:**
   - Google attribute: `google.subject`
   - Attribute value: `assertion.sub`

2. **Add Attribute Condition (Recommended):**
   - Condition: `assertion.repository == "AmanorsElliot/credovo-platform"`
   - This restricts access to your specific repository

3. **Get the Provider Resource Name:**
   - Will be: `projects/858440156644/locations/global/workloadIdentityPools/github-actions/providers/github-provider`
   - Use this for the `GCP_WIF_PROVIDER` GitHub secret

## Quick Reference

```
Provider name: GitHub Provider
Provider ID: github-provider
Issuer URL: https://token.actions.githubusercontent.com
JWK file: (leave empty)
```

