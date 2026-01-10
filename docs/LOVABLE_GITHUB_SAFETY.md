# Safely Connecting Lovable to GitHub

This guide explains how to connect Lovable to your GitHub repository without risking overwrites of backend services, infrastructure, or other critical files.

## ⚠️ Important Considerations

Lovable can sync with GitHub, but you need to configure it carefully to ensure it **only manages the frontend code** and doesn't overwrite:
- Backend services (`services/`)
- Infrastructure (`infrastructure/`)
- Shared libraries (`shared/`)
- Documentation (`docs/`)
- CI/CD workflows (`.github/`)
- Scripts (`scripts/`)

## Recommended Approach: Separate Branch Strategy

### Option 1: Use a Separate Branch for Lovable (Recommended)

**Best Practice**: Create a dedicated branch for Lovable frontend development.

1. **Create a frontend branch:**
   ```bash
   git checkout -b frontend/lovable
   git push -u origin frontend/lovable
   ```

2. **Connect Lovable to the `frontend/lovable` branch:**
   - In Lovable, connect to GitHub
   - Select branch: `frontend/lovable` (not `main`)
   - Set root directory: `/frontend/lovable-frontend` (if Lovable supports this)

3. **Merge changes safely:**
   - Review all changes from Lovable before merging
   - Merge `frontend/lovable` → `main` via pull request
   - This gives you control over what gets merged

### Option 2: Configure Lovable to Only Sync Frontend Directory

If Lovable supports directory-specific syncing:

1. **In Lovable Settings:**
   - Set repository root: `frontend/lovable-frontend`
   - Or configure it to only sync files within `/frontend/`

2. **Verify Configuration:**
   - Test with a small change first
   - Check what files Lovable tries to modify
   - Ensure it's only touching files in `/frontend/`

## Protection Mechanisms

### 1. Branch Protection Rules

Protect your `main` branch from direct pushes:

1. Go to: `https://github.com/AmanorsElliot/credovo-platform/settings/branches`
2. Add branch protection rule for `main`:
   - ✅ Require pull request reviews before merging
   - ✅ Require status checks to pass
   - ✅ Restrict who can push to matching branches
   - ✅ Include administrators (optional - for emergency fixes)

This ensures Lovable can't directly push to `main` without review.

### 2. CODEOWNERS File

Create `.github/CODEOWNERS` to require reviews for critical directories:

```gitignore
# Protect critical directories
/services/ @your-team
/infrastructure/ @your-team
/shared/ @your-team
/docs/ @your-team
/.github/ @your-team
/scripts/ @your-team

# Frontend can be managed by Lovable
/frontend/ @lovable-team
```

### 3. GitHub Actions Path Filters

Ensure your CI/CD workflows only trigger on relevant changes:

```yaml
# Example: Only run backend tests on backend changes
on:
  push:
    paths:
      - 'services/**'
      - 'shared/**'
      - '.github/workflows/**'
```

## Testing the Connection Safely

### Step 1: Create a Test Branch

```bash
git checkout -b test/lovable-connection
git push -u origin test/lovable-connection
```

### Step 2: Connect Lovable to Test Branch

1. In Lovable, connect to GitHub
2. Select branch: `test/lovable-connection`
3. Make a small test change (e.g., update a comment)

### Step 3: Review What Changed

```bash
git diff test/lovable-connection main
```

**Check:**
- ✅ Only files in `/frontend/` were modified
- ❌ No changes to `services/`, `infrastructure/`, `shared/`, etc.

### Step 4: If Safe, Merge to Main

If only frontend files changed:
```bash
git checkout main
git merge test/lovable-connection
git push origin main
```

## What Lovable Should Manage

**✅ Safe for Lovable:**
- `/frontend/lovable-frontend/` - All frontend code
- Frontend configuration files (package.json, tsconfig.json in frontend/)
- Frontend environment variables (if stored in frontend/)

**❌ Never Let Lovable Touch:**
- `/services/` - Backend microservices
- `/infrastructure/` - Terraform configurations
- `/shared/` - Shared libraries
- `/docs/` - Documentation
- `/.github/` - CI/CD workflows
- `/scripts/` - Deployment scripts
- Root-level configuration files (unless frontend-specific)

## Monitoring Lovable Changes

### Set Up Alerts

Create a GitHub Action to alert on changes outside `/frontend/`:

```yaml
# .github/workflows/monitor-lovable-changes.yml
name: Monitor Lovable Changes
on:
  pull_request:
    paths:
      - 'frontend/**'
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Check for non-frontend changes
        run: |
          if git diff --name-only origin/main...HEAD | grep -v "^frontend/"; then
            echo "⚠️ WARNING: Changes detected outside /frontend/"
            exit 1
          fi
```

### Review Pull Requests Carefully

Always review PRs from Lovable:
1. Check the "Files changed" tab
2. Verify only frontend files are modified
3. Reject if backend/infrastructure files are changed

## Alternative: Separate Repository

If you're still concerned, consider:

**Option: Separate Frontend Repository**
- Create `credovo-frontend` repository
- Keep backend/infrastructure in `credovo-platform`
- Connect Lovable only to `credovo-frontend`
- Use Git submodules or package dependencies to link them

This completely isolates frontend from backend, but adds complexity.

## Current Repository Structure

Your current structure is:
```
credovo-platform/
├── frontend/lovable-frontend/  ← Lovable should only touch this
├── services/                    ← Protected
├── infrastructure/              ← Protected
├── shared/                     ← Protected
├── docs/                        ← Protected
└── scripts/                     ← Protected
```

## Recommended Workflow

1. **Development:**
   - Work in `frontend/lovable-frontend` branch
   - Lovable syncs to this branch
   - Make changes in Lovable

2. **Review:**
   - Create PR from `frontend/lovable-frontend` → `main`
   - Review changes (ensure only frontend files)
   - Run CI/CD checks

3. **Merge:**
   - Merge PR to `main`
   - Cloud Build automatically deploys backend changes
   - Frontend deploys separately (via Lovable or your frontend hosting)

## Troubleshooting

**If Lovable tries to modify non-frontend files:**

1. **Immediately:**
   - Reject the PR
   - Check Lovable settings
   - Verify branch protection is enabled

2. **Fix:**
   - Update Lovable configuration
   - Ensure it's pointing to correct directory
   - Consider using separate branch

3. **Recover:**
   - If files were overwritten, restore from git history:
     ```bash
     git checkout main -- services/
     git checkout main -- infrastructure/
     ```

## Summary

**Best Practice:**
1. ✅ Use separate branch (`frontend/lovable-frontend`)
2. ✅ Enable branch protection on `main`
3. ✅ Use CODEOWNERS for critical directories
4. ✅ Always review PRs before merging
5. ✅ Test connection on a test branch first

**This ensures Lovable can only modify frontend code, protecting all your backend services and infrastructure.**

