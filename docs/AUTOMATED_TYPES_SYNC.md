# Automated Types Sync

This guide explains how to automatically keep shared types in sync between `credovo-platform` and `credovo-webapp`.

## The Problem

When types change in `credovo-platform/shared/types/index.ts`, you need to manually update them in `credovo-webapp`. This is error-prone and easy to forget.

## Solutions

### Option 1: Publish to Public npm (Recommended) ⭐

**Best for**: Long-term maintenance, no manual syncing

Publish the package to public npm instead of (or in addition to) GitHub Packages:

1. **Publish to npm:**
   ```powershell
   .\scripts\publish-to-npm.ps1
   ```

2. **Install in credovo-webapp:**
   ```bash
   npm install @amanorselliot/shared-types
   ```

3. **Update when types change:**
   ```bash
   # In credovo-platform
   # Edit shared/types/index.ts
   npm version patch  # or minor, major
   .\scripts\publish-to-npm.ps1
   
   # In credovo-webapp
   npm update @amanorselliot/shared-types
   ```

**Benefits:**
- ✅ Standard npm workflow
- ✅ Version management
- ✅ Works in Lovable without registry config
- ✅ Automatic updates via `npm update`

### Option 2: GitHub Actions Auto-Sync

**Best for**: Keeping types in sync automatically

A GitHub Action automatically syncs types when they change:

1. **Action is already set up**: `.github/workflows/sync-types-to-webapp.yml`

2. **How it works:**
   - Monitors `shared/types/index.ts` for changes
   - When changed, automatically copies to `credovo-webapp/src/types/shared-types.ts`
   - Creates a PR in `credovo-webapp` for review
   - Or commits directly (configurable)

3. **To enable:**
   - Ensure `credovo-webapp` repository exists
   - Action will run automatically on pushes to `main`
   - Review and merge PRs in `credovo-webapp`

**Benefits:**
- ✅ Fully automated
- ✅ No manual copying
- ✅ PR review before merging
- ✅ Commit history shows syncs

**Setup:**
- Action is already configured
- Runs automatically when `shared/types/index.ts` changes
- Creates PRs in `credovo-webapp` for review

### Option 3: Manual Sync Script

**Best for**: On-demand syncing

Run the script when you need to sync:

```powershell
.\scripts\copy-shared-types-to-webapp.ps1
```

**Benefits:**
- ✅ Simple and immediate
- ✅ Full control over when to sync

**Cons:**
- ❌ Manual step required
- ❌ Easy to forget

## Recommended Workflow

### For Development: npm Package ⭐

1. **Initial Setup (one-time):**
   ```bash
   # Create npm account if needed
   # https://www.npmjs.com/signup
   
   # Enable 2FA (required for publishing)
   # Go to: https://www.npmjs.com/settings/YOUR_USERNAME/two-factor/auth
   # Enable 2FA using TOTP app (Google Authenticator, Authy, etc.)
   
   # Login to npm (will prompt for 2FA code)
   npm login
   ```
   
   **Note**: npm requires 2FA to publish packages. You can also use a granular access token with "bypass 2fa" enabled instead.

2. **Publish to npm:**
   ```powershell
   .\scripts\publish-to-npm.ps1
   ```

3. **Use in credovo-webapp:**
   ```bash
   npm install @amanorselliot/shared-types
   ```

4. **Update workflow (when types change):**
   ```powershell
   # In credovo-platform/shared/types
   cd shared/types
   
   # Edit index.ts with your changes
   # Then:
   npm version patch  # Bumps version (1.0.0 → 1.0.1)
   cd ../..
   .\scripts\publish-to-npm.ps1
   
   # In credovo-webapp
   npm update @amanorselliot/shared-types
   ```

### For Automation: GitHub Actions

The GitHub Action (`.github/workflows/sync-types-to-webapp.yml`) will:
- Automatically detect type changes
- Copy to `credovo-webapp`
- Create a PR for review

## Comparison

| Solution | Automation | Versioning | Lovable Support | Maintenance |
|----------|-----------|------------|-----------------|-------------|
| npm Package | Manual update | ✅ Semantic | ✅ Works | Low |
| GitHub Actions | ✅ Fully auto | ❌ No versioning | ✅ Works | Very Low |
| Manual Copy | ❌ Manual | ❌ No versioning | ✅ Works | High |

## Recommendation

**Use npm Package** for the best balance:
- Standard workflow
- Version management
- Works in Lovable
- Easy updates

The GitHub Action is a good backup for automatic syncing if you prefer the copy approach.

