# Policy Issue: restoreDefault is Blocking Inheritance

## Root Cause Found!

The **non-prod folder** has `restoreDefault: {}` set in its configured policy. This resets the policy to the default restrictive policy, which blocks inheritance from the parent (`eu-gdpr`).

## What's Happening

### Non-Prod Folder (351913445774)
```json
{
  "constraint": "constraints/gcp.restrictServiceUsage",
  "restoreDefault": {}
}
```
- **Problem**: `restoreDefault` resets to default restrictive policy
- **Result**: Limited permissions, doesn't inherit from eu-gdpr

### Prod Folder (1014610384094)
```json
{
  "constraint": "constraints/gcp.restrictServiceUsage"
}
```
- **No restoreDefault**: Fully inherits from eu-gdpr
- **Result**: Wide permissions (102+ services)

### Projects
Both projects have empty policies (just constraint), so they inherit from their parent folders.

## Solution

Remove the `restoreDefault` from the non-prod folder policy. This will allow it to properly inherit from `eu-gdpr`.

### Option 1: Set Policy to Inherit (Recommended)

Set the non-prod folder policy to explicitly inherit:

```powershell
# Create a policy JSON that inherits from parent
$policyJson = @{
    constraint = "constraints/gcp.restrictServiceUsage"
} | ConvertTo-Json

# Set the policy (this removes restoreDefault)
echo $policyJson | gcloud resource-manager org-policies set-policy - `
    --folder=351913445774
```

### Option 2: Use Console

1. Go to IAM & Admin → Organization Policies
2. Select folder "non-prod"
3. Find `gcp.restrictServiceUsage` constraint
4. Click "Edit policy"
5. Select "Inherit parent's policy"
6. Save

### Option 3: Delete the Policy

If the policy is set to inherit, you can delete the explicit policy to let it fully inherit:

```powershell
# Delete the policy (will inherit from parent)
gcloud resource-manager org-policies delete gcp.restrictServiceUsage `
    --folder=351913445774
```

## Verification

After removing `restoreDefault`:

```powershell
# Check effective policy (should now match eu-gdpr)
gcloud resource-manager org-policies describe gcp.restrictServiceUsage `
    --effective `
    --folder=351913445774 `
    --format="json" | ConvertFrom-Json | Select-Object -ExpandProperty listPolicy

# Should show many services, not just a few
```

## Why This Happened

When you set a policy to "inherit from parent" in the console, if there was previously a restrictive policy, it might have set `restoreDefault` instead of truly inheriting. The `restoreDefault` flag resets to the default restrictive policy rather than inheriting from the parent.

## Summary

- **Problem**: `restoreDefault: {}` in non-prod folder policy
- **Solution**: Remove `restoreDefault` and set to inherit from parent
- **Result**: Non-prod will inherit wide permissions from eu-gdpr, matching prod
