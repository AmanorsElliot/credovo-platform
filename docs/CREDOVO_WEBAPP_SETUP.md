# Credovo Webapp Setup Guide

This guide helps you set up the `credovo-webapp` repository with the shared types package and connect it to Lovable.

## Repository

**GitHub Repository**: `https://github.com/AmanorsElliot/credovo-webapp`

Clone the repository:
```bash
git clone https://github.com/AmanorsElliot/credovo-webapp.git
cd credovo-webapp
```

## Prerequisites

1. ✅ `credovo-webapp` repository created (local and on GitHub)
2. ✅ `@credovo/shared-types` package published
3. ✅ Node.js and npm installed

## Step 1: Publish Shared Types Package

From the `credovo-platform` repository:

```bash
# Clone if you haven't already
git clone https://github.com/AmanorsElliot/credovo-platform.git
cd credovo-platform

# Publish the package
.\scripts\publish-shared-types.ps1
# Or on Linux/Mac:
# bash scripts/publish-shared-types.sh
```

This will:
- Build the TypeScript types
- Publish to GitHub Packages (or npm)

## Step 2: Initialize credovo-webapp

```bash
# Clone the repository if you haven't already
git clone https://github.com/AmanorsElliot/credovo-webapp.git
cd credovo-webapp

# Initialize npm if not already done
npm init -y
```

## Step 3: Configure .npmrc for GitHub Packages

**Important**: Create `.npmrc` in `credovo-webapp` root to configure scope-specific registry:

```ini
@credovo:registry=https://npm.pkg.github.com
//npm.pkg.github.com/:_authToken=YOUR_GITHUB_TOKEN
```

This ensures:
- `@amanorselliot/*` packages are fetched from GitHub Packages
- All other packages use the default npm registry

### Get GitHub Token

1. Go to: https://github.com/settings/tokens
2. Generate new token (classic)
3. Select `read:packages` scope (and `write:packages` if you'll publish)
4. Copy the token and replace `YOUR_GITHUB_TOKEN` in `.npmrc`

### Alternative: Environment Variable

Instead of storing token in `.npmrc`, you can use an environment variable:

```bash
# Windows PowerShell
$env:NPM_TOKEN="YOUR_GITHUB_TOKEN"
```

Then in `.npmrc`:
```ini
@credovo:registry=https://npm.pkg.github.com
//npm.pkg.github.com/:_authToken=${NPM_TOKEN}
```

## Step 4: Install Shared Types

**Recommended**: Install from public npm (no registry config needed)

```bash
# Ensure you're in the credovo-webapp directory
cd credovo-webapp

# Install shared types from npm
npm install @credovo/shared-types
```

**Alternative**: If using GitHub Packages, configure `.npmrc`:
```ini
@credovo:registry=https://npm.pkg.github.com
//npm.pkg.github.com/:_authToken=YOUR_GITHUB_TOKEN
```

Then install:
```bash
npm install @credovo/shared-types
```

## Step 5: Install Frontend Dependencies

```bash
# Ensure you're in the credovo-webapp directory
cd credovo-webapp

# Install React and other frontend dependencies
npm install react react-dom
npm install --save-dev @types/react @types/react-dom

# Install build tools
npm install --save-dev typescript @types/node
npm install --save-dev vite @vitejs/plugin-react  # or your preferred build tool
```

## Step 6: Configure TypeScript

Create `tsconfig.json` in `credovo-webapp`:

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ESNext",
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "jsx": "react-jsx",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "moduleResolution": "node",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true
  },
  "include": ["src"],
  "exclude": ["node_modules"]
}
```

## Step 7: Use Shared Types

In your frontend code:

```typescript
import { KYCRequest, KYCResponse, KYBRequest, KYBResponse } from '@credovo/shared-types';

// Example usage
const kycRequest: KYCRequest = {
  applicationId: 'app-123',
  userId: 'user-456',
  type: 'individual',
  data: {
    firstName: 'John',
    lastName: 'Doe',
    dateOfBirth: '1990-01-01',
    address: {
      line1: '123 Main St',
      city: 'London',
      postcode: 'SW1A 1AA',
      country: 'GB'
    }
  }
};
```

## Step 8: Configure Environment Variables

Create `.env` or `.env.local` in `credovo-webapp`:

```env
REACT_APP_API_URL=https://orchestration-service-saz24fo3sa-ew.a.run.app
REACT_APP_LOVABLE_AUTH_URL=https://auth.lovable.dev
```

Or for Vite:
```env
VITE_API_URL=https://orchestration-service-saz24fo3sa-ew.a.run.app
VITE_LOVABLE_AUTH_URL=https://auth.lovable.dev
```

## Step 9: Connect to Lovable

1. **In Lovable:**
   - Go to Settings → GitHub Integration
   - Connect to `credovo-webapp` repository
   - Select branch: `main` (or your default branch)
   - No restrictions needed - entire repo is frontend!

2. **Verify Connection:**
   - Make a small test change in Lovable
   - Verify it syncs to GitHub
   - Check that only frontend files are modified

## Step 10: Update Backend CORS

Update `orchestration-service` to allow requests from Lovable:

File: `credovo-platform/services/orchestration-service/src/index.ts`

```typescript
const allowedOrigins = [
  'https://your-app.lovable.app',  // Your Lovable app URL
  'http://localhost:3000',          // Local development
  'http://localhost:5173',          // Vite dev server
];
```

## Updating Shared Types

When types change in `credovo-platform`:

1. **Update types in backend:**
   ```bash
   cd credovo-platform
   # Edit shared/types/index.ts
   ```

2. **Publish new version:**
   ```bash
   cd credovo-platform
   .\scripts\publish-shared-types.ps1
   # Or on Linux/Mac:
   # bash scripts/publish-shared-types.sh
   ```

3. **Update in frontend:**
   ```bash
   cd credovo-webapp
   npm update @amanorselliot/shared-types
   ```

## Project Structure

```
credovo-webapp/
├── src/
│   ├── components/
│   ├── pages/
│   ├── utils/
│   └── App.tsx
├── package.json
├── tsconfig.json
├── .env.local
├── .npmrc (for GitHub Packages)
└── README.md
```

## Troubleshooting

### Package Not Found

If `npm install @credovo/shared-types` fails:

1. **Check .npmrc configuration:**
   ```bash
   cat .npmrc
   ```
   Should contain:
   ```
   @credovo:registry=https://npm.pkg.github.com
   //npm.pkg.github.com/:_authToken=YOUR_TOKEN
   ```

2. **Check GitHub Packages access:**
   - Ensure you have access to the `credovo-platform` repository
   - Verify GitHub token has `read:packages` scope

3. **Verify token:**
   - Check token hasn't expired
   - Regenerate if needed

### Integrity Errors

If you see integrity errors for other packages (like `@types/ws`, `@types/d3-path`):

**Problem**: npm is trying to use GitHub Packages for ALL packages.

**Solution**: Ensure `.npmrc` uses scope-specific registry:
```ini
@credovo:registry=https://npm.pkg.github.com
```

**NOT**:
```ini
registry=https://npm.pkg.github.com  # ❌ This makes ALL packages use GitHub Packages
```

### Type Errors

If TypeScript can't find types:

1. **Check node_modules:**
   ```bash
   ls node_modules/@credovo/shared-types
   ```

2. **Verify package.json:**
   ```bash
   cat node_modules/@credovo/shared-types/package.json
   ```

3. **Restart TypeScript server:**
   - In VS Code: `Ctrl+Shift+P` → "TypeScript: Restart TS Server"

### Lovable Sync Issues

If Lovable isn't syncing:

1. **Check GitHub connection:**
   - Verify repository is connected
   - Check branch name matches

2. **Check permissions:**
   - Ensure Lovable has write access
   - Verify branch protection rules

## Next Steps

- ✅ Set up authentication with Lovable Cloud
- ✅ Create API client for backend services
- ✅ Build KYC/KYB forms
- ✅ Connect to orchestration service
- ✅ Deploy frontend (Vercel, Netlify, etc.)

## Related Documentation

- [Lovable Separate Repo Guide](LOVABLE_SEPARATE_REPO.md) - Detailed separate repo strategy
- [Service Interactions](SERVICE_INTERACTIONS.md) - How backend services work
- [Authentication Guide](AUTHENTICATION.md) - Auth setup
