# Installing Private GitHub Packages in Lovable

This guide explains how to use `@amanorselliot/shared-types` in your Lovable frontend project.

## The Challenge

Lovable can install public npm packages easily, but private GitHub npm packages require authentication. Since Lovable runs in a managed environment, configuring `.npmrc` with tokens can be challenging.

## Solution Options

### Option 1: Make Package Public (Recommended) ⭐

**Best for**: Simplest setup, no authentication needed

GitHub Packages can be made public! This is the easiest solution:

1. **Make the package public:**
   - Go to: https://github.com/AmanorsElliot/credovo-platform/packages
   - Find `@amanorselliot/shared-types`
   - Click "Package settings"
   - Change visibility to "Public"

2. **Install in Lovable:**
   ```bash
   npm install @amanorselliot/shared-types --registry=https://npm.pkg.github.com
   ```

   Or configure `.npmrc`:
   ```ini
   @amanorselliot:registry=https://npm.pkg.github.com
   ```

   **No authentication token needed for public packages!**

### Option 2: Publish to Public npm (Alternative)

**Best for**: Standard npm workflow, no GitHub dependency

1. **Publish to npm:**
   ```bash
   cd credovo-platform/shared/types
   npm publish --access public
   ```

2. **Install in Lovable:**
   ```bash
   npm install @amanorselliot/shared-types
   ```

   No special configuration needed!

### Option 3: Copy Types Directly (Fallback)

**Best for**: When authentication isn't possible, simple types-only package

Since `@amanorselliot/shared-types` is just TypeScript types, you can copy them directly:

1. **Copy types file:**
   ```bash
   # In credovo-webapp
   mkdir -p src/types
   # Copy from credovo-platform/shared/types/index.ts
   cp ../credovo-platform/shared/types/index.ts src/types/shared-types.ts
   ```

2. **Use in code:**
   ```typescript
   // Instead of: import { KYCRequest } from '@amanorselliot/shared-types'
   import { KYCRequest } from './types/shared-types';
   ```

3. **Keep in sync:**
   - Manually update when types change
   - Or create a script to sync automatically

**Pros:**
- ✅ No authentication needed
- ✅ Works immediately in Lovable
- ✅ No registry configuration

**Cons:**
- ❌ Manual sync required
- ❌ Loses single source of truth
- ❌ Version management is manual

### Option 4: Configure Lovable with .npmrc (If Supported)

**Best for**: When Lovable supports .npmrc configuration

1. **Create `.npmrc` in credovo-webapp:**
   ```ini
   @amanorselliot:registry=https://npm.pkg.github.com
   //npm.pkg.github.com/:_authToken=${GITHUB_TOKEN}
   ```

2. **Set environment variable in Lovable:**
   - Add `GITHUB_TOKEN` as an environment variable
   - Use a GitHub Personal Access Token with `read:packages` scope

3. **Install:**
   ```bash
   npm install @amanorselliot/shared-types
   ```

**Note**: Check if Lovable supports `.npmrc` files and environment variables for npm authentication.

## Recommended Approach

### For Development: Option 1 (Public GitHub Package)

1. Make the package public on GitHub Packages
2. Configure `.npmrc` with scope-specific registry (no token needed)
3. Install normally

### For Production: Option 2 (Public npm)

1. Publish to public npm registry
2. Standard npm install (no special config)
3. Better for production deployments

### Quick Start: Option 3 (Copy Types)

If you need to get started immediately:
1. Copy `shared/types/index.ts` to `credovo-webapp/src/types/shared-types.ts`
2. Update imports to use local file
3. Sync manually when types change

## Making GitHub Package Public

1. **Via GitHub Web UI:**
   - Navigate to: https://github.com/AmanorsElliot/credovo-platform/packages
   - Click on `@amanorselliot/shared-types`
   - Go to "Package settings"
   - Under "Danger Zone", click "Change visibility"
   - Select "Public"
   - Confirm

2. **Verify:**
   ```bash
   # Should work without authentication
   npm view @amanorselliot/shared-types --registry=https://npm.pkg.github.com
   ```

## Updating Documentation

After making the package public, update `credovo-webapp` documentation:

```markdown
## Installation

```bash
npm install @amanorselliot/shared-types --registry=https://npm.pkg.github.com
```

Or with `.npmrc`:
```ini
@amanorselliot:registry=https://npm.pkg.github.com
```

Then:
```bash
npm install @amanorselliot/shared-types
```
```

## Summary

| Option | Complexity | Maintenance | Recommended For |
|--------|-----------|-------------|-----------------|
| Public GitHub Package | ⭐ Low | ⭐ Easy | Development |
| Public npm | ⭐ Low | ⭐ Easy | Production |
| Copy Types | ⭐⭐ Medium | ⭐⭐ Manual | Quick start |
| Private with Auth | ⭐⭐⭐ High | ⭐⭐⭐ Complex | Enterprise |

**Recommendation**: Start with **Option 1** (make package public) for the simplest setup. If you need it private, use **Option 3** (copy types) as a fallback.

