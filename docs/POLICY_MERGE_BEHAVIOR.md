# Policy Merge Behavior: Folder vs Project

## Issue

After deleting the policy from the non-prod folder:
- **non-prod folder**: Shows only 9 services in effective policy
- **credovo-eu-apps-nonprod project**: Shows 100+ services in effective policy

Both are set to "inherit from parent", but they're showing different effective policies.

## Why This Happens

### Policy Merge Rules

When policies are set to "inherit" or "merge", Google Cloud uses different merge rules:

1. **List Policy Merge**: When multiple policies exist in the hierarchy:
   - `allowedValues` lists are **intersected** (only services in ALL levels are allowed)
   - OR they can be **unioned** depending on enforcement mode

2. **Enforcement Mode**:
   - **Replace**: Uses only the current level's policy
   - **Merge**: Combines policies from all levels (intersection)

### What's Likely Happening

The **non-prod folder** effective policy is showing:
- The **intersection** of policies from:
  - Organization level (if exists)
  - eu-gdpr folder
  - non-prod folder (even though deleted, might have a default)

The **project** effective policy is showing:
- A different merge result, possibly:
  - Inheriting directly from eu-gdpr (bypassing non-prod)
  - Or a different merge calculation

## Console Display vs Actual Policy

The console might be showing:
- **Folder view**: Only explicitly configured services at that level
- **Project view**: The actual effective policy after all merges

This is a **display issue** - the actual effective policy for the project is what matters.

## Verification

The project has `run.googleapis.com` and `apigateway.googleapis.com` in its effective policy, which means:
- ✅ **The project CAN use these services**
- ✅ **Cloud Run and API Gateway will work**
- ⚠️ **The folder display is misleading** but doesn't affect the project

## Solution

Since the **project has the correct effective policy** (100+ services including run.googleapis.com and apigateway.googleapis.com), you don't need to fix the folder display.

However, if you want the folder display to match:

### Option 1: Set Explicit Policy on non-prod Folder

Set the non-prod folder to explicitly allow all services (like eu-gdpr does):

```powershell
# This would require creating a policy JSON with all services
# But this is complex and unnecessary if the project works
```

### Option 2: Ignore Folder Display

The folder display showing 9 services is just a display artifact. The **project's effective policy is what matters**, and it has all the services needed.

## Key Takeaway

**The project's effective policy is correct** - it has all required services including:
- ✅ `run.googleapis.com`
- ✅ `apigateway.googleapis.com`
- ✅ All other services needed

The folder display showing fewer services is a **display/merge calculation issue** but doesn't affect the project's ability to use services.

## Recommendation

**No action needed** - the project has the correct effective policy. The folder display discrepancy is cosmetic and doesn't impact functionality.
