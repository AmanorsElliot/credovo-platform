# Policy Inheritance Solution: Non-Prod vs Prod Discrepancy

## Issue Summary

After setting all layers to "inherit from parent":
- ✅ **Prod folder and project**: Have wide permissions (102+ services)
- ❌ **Non-prod folder and project**: Show `allValues: "ALLOW"` but user reports limited permissions

## Key Finding

The **non-prod folder effective policy shows `allValues: "ALLOW"`**, which should allow ALL services. However, the user is seeing limited permissions.

## Possible Explanations

### 1. Policy Merge with Deny List
Even if `allValues: "ALLOW"` is set, there might be:
- A `deniedValues` list that overrides the allow
- A parent policy with a deny list that merges
- An organization-level policy with restrictions

### 2. Policy Enforcement Mode
The policy enforcement mode (Merge vs Replace) affects how policies combine:
- **Merge**: Combines allow/deny lists from all levels
- **Replace**: Uses only the current level's policy

### 3. Policy Conditions
There might be conditions that:
- Apply differently to non-prod vs prod
- Restrict services based on environment tags
- Have time-based or resource-based conditions

### 4. Console Display Issue
The console might be showing:
- Only explicitly configured services (not inherited)
- A cached view that hasn't updated
- A filtered view based on some criteria

## Investigation Commands

### Check for Deny Lists

```powershell
# Check non-prod folder for denied values
gcloud resource-manager org-policies describe gcp.restrictServiceUsage `
    --effective `
    --folder=351913445774 `
    --format="json" | ConvertFrom-Json | Select-Object -ExpandProperty listPolicy

# Check non-prod project for denied values
gcloud resource-manager org-policies describe gcp.restrictServiceUsage `
    --effective `
    --project=credovo-eu-apps-nonprod `
    --format="json" | ConvertFrom-Json | Select-Object -ExpandProperty listPolicy
```

### Check Policy Enforcement Mode

```powershell
# Check configured policy (not effective) to see enforcement mode
gcloud resource-manager org-policies describe gcp.restrictServiceUsage `
    --folder=351913445774 `
    --format="yaml" | Select-String "merge|replace|inherit"
```

### Compare Configured vs Effective

```powershell
# Non-prod folder configured
gcloud resource-manager org-policies describe gcp.restrictServiceUsage `
    --folder=351913445774 `
    --format="json"

# Non-prod folder effective
gcloud resource-manager org-policies describe gcp.restrictServiceUsage `
    --effective `
    --folder=351913445774 `
    --format="json"
```

## Likely Cause

The most likely cause is that:
1. **non-prod folder** has `allValues: "ALLOW"` set (inherited or configured)
2. But there's a **deny list** somewhere in the hierarchy that's blocking services
3. Or the **policy enforcement mode** is "Merge" which combines restrictions

## Solution

### Option 1: Check for Deny Lists
Remove any `deniedValues` lists that might be restricting services.

### Option 2: Change Enforcement Mode
If using "Merge", consider changing to "Replace" to use only the current level's policy.

### Option 3: Explicit Allow List
Instead of `allValues: "ALLOW"`, explicitly list all required services (like prod does).

## Next Steps

1. Run the investigation commands above
2. Check for `deniedValues` in the policy hierarchy
3. Verify policy enforcement mode
4. Compare with prod folder configuration to see what's different
