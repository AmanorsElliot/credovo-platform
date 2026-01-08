# Workload Identity Provider - Attribute Mapping Configuration

## Step 1: Attribute Mapping

You need to map GitHub's OIDC claims to Google attributes.

### Current State
- **Google 1**: `google.subject` ✅ (already filled)
- **OIDC 1**: ❌ (empty - needs to be filled)

### What to Enter

In the **"OIDC 1"** field, enter:
```
assertion.sub
```

This maps GitHub's subject claim (which contains the repository and workflow info) to Google's subject attribute.

### Why This Mapping?

- `google.subject` = The Google identity attribute
- `assertion.sub` = GitHub's subject claim from the OIDC token
- GitHub's subject format: `repo:AmanorsElliot/credovo-platform:ref:refs/heads/main`

## Step 2: Attribute Condition (Recommended)

Click **"Add condition"** at the bottom of the page.

Enter this condition:
```
assertion.repository == "AmanorsElliot/credovo-platform"
```

### Why Add This Condition?

- **Security**: Restricts authentication to only your repository
- **Prevents unauthorized access**: Other repositories can't use this provider
- **Best practice**: Always restrict Workload Identity to specific repositories

### Alternative Conditions (Optional)

You can also restrict by branch or environment:
```
# Only main branch
assertion.ref == "refs/heads/main"

# Specific environment
assertion.environment == "production"

# Combined (repository AND branch)
assertion.repository == "AmanorsElliot/credovo-platform" && assertion.ref == "refs/heads/main"
```

For now, the repository condition is sufficient.

## Summary

**Attribute Mapping:**
- Google: `google.subject`
- OIDC: `assertion.sub`

**Attribute Condition:**
```
assertion.repository == "AmanorsElliot/credovo-platform"
```

After saving, you'll have the provider set up and can get the resource name for GitHub secrets!

