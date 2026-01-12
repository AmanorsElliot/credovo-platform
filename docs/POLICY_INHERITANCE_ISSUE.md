# Policy Inheritance Issue: Non-Prod vs Prod

## Problem

After setting all layers to "inherit from parent":
- ✅ **Prod folder and project**: Have wide permissions (many services allowed)
- ❌ **Non-prod folder and project**: Have very limited permissions (few services allowed)

Both should inherit from the same parent (`eu-gdpr` folder), but they're getting different effective policies.

## Hierarchy Structure

```
eu-gdpr (folder 1036514635790)
  ├── non-prod (folder 351913445774) ← Limited permissions
  │   └── credovo-eu-apps-nonprod (project) ← Limited permissions
  └── prod (folder 1014610384094) ← Wide permissions
      └── credovo-eu-apps-prod (project) ← Wide permissions
```

## Possible Causes

### 1. Policy Merge Rules
When using "Merge with parent" (instead of "Replace"), policies are combined:
- If a parent has a restrictive policy and a child has a restrictive policy, they merge
- "Deny" overrides "allow" in merge scenarios
- This could explain why non-prod is more restricted

### 2. Different Policy Enforcement Settings
- **non-prod folder**: Might have "Merge with parent" instead of "Replace"
- **prod folder**: Might have "Replace" which ignores parent restrictions
- This would cause different effective policies

### 3. Organization-Level Policy
There might be an organization-level policy that:
- Applies differently to prod vs non-prod
- Has conditions based on folder names
- Has different merge rules

### 4. Policy Conditions
There might be conditions on policies that:
- Apply to non-prod but not prod
- Restrict services based on environment
- Have different effective dates

## Investigation Steps

### Step 1: Check Policy Enforcement Mode

```powershell
# Check non-prod folder policy enforcement
gcloud resource-manager org-policies describe gcp.restrictServiceUsage `
    --folder=351913445774 `
    --format="yaml" | Select-String "merge|replace"

# Check prod folder policy enforcement  
gcloud resource-manager org-policies describe gcp.restrictServiceUsage `
    --folder=1014610384094 `
    --format="yaml" | Select-String "merge|replace"
```

### Step 2: Check for Organization-Level Policy

```powershell
# Check if there's an org-level policy
gcloud resource-manager org-policies list `
    --organization=<org-id> `
    --filter="constraint:gcp.restrictServiceUsage"
```

### Step 3: Compare Configured vs Effective Policies

```powershell
# Non-prod configured policy
gcloud resource-manager org-policies describe gcp.restrictServiceUsage `
    --folder=351913445774 `
    --format="yaml"

# Non-prod effective policy
gcloud resource-manager org-policies describe gcp.restrictServiceUsage `
    --effective `
    --folder=351913445774 `
    --format="yaml"

# Compare the two to see what's being inherited/merged
```

### Step 4: Check Policy Conditions

```powershell
# Check if there are conditions on the policies
gcloud resource-manager org-policies describe gcp.restrictServiceUsage `
    --folder=351913445774 `
    --format="yaml" | Select-String "condition"
```

## Likely Solution

The issue is probably that:
1. **non-prod folder** has "Merge with parent" enforcement mode
2. **prod folder** has "Replace" enforcement mode
3. When merging, restrictive policies combine to create fewer allowed services

**Fix**: Change non-prod folder policy enforcement from "Merge" to "Replace" (or ensure both use the same mode).

## Immediate Workaround

If you need non-prod to work immediately:
1. Set non-prod folder to "Override parent's policy" (Replace)
2. Explicitly list all required services
3. This matches what prod is doing (effectively)

## Next Steps

1. Verify policy enforcement modes for both folders
2. Check for organization-level policies
3. Compare configured vs effective policies
4. Fix the enforcement mode or add explicit policy to non-prod
