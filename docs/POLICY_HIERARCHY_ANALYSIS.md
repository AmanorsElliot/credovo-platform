# Policy Hierarchy Analysis

## Policy Hierarchy Structure

```
Organization (or higher)
  └── Folder "eu-gdpr" (Override parent)
      └── Folder "non-prod" (Inherit from eu-gdpr)
          └── Project "Credovo EU Apps Nonprod" (Override parent)
```

## Current Policy States

### Folder "eu-gdpr" (Parent of non-prod)
- **Policy source**: Override parent's policy
- **Has `run.googleapis.com`**: ✅ YES (in configured policy)
- **Has `apigateway.googleapis.com`**: ✅ YES (in configured policy)
- **Effective policy**: Includes both services

### Folder "non-prod" (Parent of project)
- **Policy source**: Inherit parent's policy (from eu-gdpr)
- **Effective policy**: Shows 9 services, **missing `run.googleapis.com`**
- **Has `apigateway.googleapis.com`**: ✅ YES
- **Issue**: Even though it inherits from eu-gdpr (which has run.googleapis.com), the effective policy doesn't show it

### Project "Credovo EU Apps Nonprod"
- **Policy source**: Override parent's policy
- **Has `run.googleapis.com`**: ✅ YES
- **Has `apigateway.googleapis.com`**: ✅ YES
- **Effective policy**: All 10 services including both

## Key Finding

**The folder "eu-gdpr" already has `run.googleapis.com` and `apigateway.googleapis.com` in its configured policy!**

However, the folder "non-prod" (which inherits from eu-gdpr) shows an effective policy that doesn't include `run.googleapis.com`, even though eu-gdpr has it.

## Why This Happens

The folder "non-prod" inherits from "eu-gdpr", but there might be:
1. A policy at a higher level (organization) that's restricting it
2. A policy merge issue
3. The effective policy display might not be showing the full inheritance

## Can You Switch to Inherit?

### Analysis

Since the project currently overrides and has all required services, and the parent folder "non-prod" inherits from "eu-gdpr" (which has the services), you **could potentially** switch to inherit.

However, there's a **risk**:
- The effective policy for "non-prod" doesn't show `run.googleapis.com`
- If you inherit from "non-prod", you might not get `run.googleapis.com`
- This would break Cloud Run services

### Recommendation

**Option 1: Keep Override (Safest)**
- ✅ Guaranteed to work
- ✅ Explicit control
- ✅ No risk of breaking services

**Option 2: Switch to Inherit (After Verification)**
- ⚠️ **First verify** that inheriting from "non-prod" actually gives you `run.googleapis.com`
- ⚠️ Test in a non-production environment first
- ⚠️ Have a rollback plan

## Verification Steps Before Switching

1. **Check if "non-prod" effective policy actually includes run.googleapis.com**:
   - The display might be incomplete
   - Check via API: `gcloud resource-manager org-policies describe gcp.restrictServiceUsage --folder=<non-prod-folder-id>`

2. **Test inheritance**:
   - Create a test project under "non-prod"
   - Set it to inherit
   - Verify it can use Cloud Run

3. **Check organization-level policies**:
   - There might be a higher-level policy affecting inheritance

## Current Status

✅ **Project policy works correctly** - Has all required services  
✅ **eu-gdpr folder has required services** - run.googleapis.com and apigateway.googleapis.com  
⚠️ **non-prod folder effective policy unclear** - Doesn't show run.googleapis.com in display  

## Recommendation

**Keep "Override parent's policy" for now** until you can verify that inheriting from "non-prod" actually provides `run.googleapis.com`. The risk of breaking Cloud Run services is too high without verification.

If you want to switch to inherit:
1. First verify the effective policy for "non-prod" via API
2. Test with a non-production project
3. Then switch the main project
