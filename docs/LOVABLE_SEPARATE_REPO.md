# Separate Repository Strategy for Lovable Frontend

## Why a Separate Repository?

**Recommended Approach**: Keep the frontend in a completely separate repository (`credovo-webapp`) for maximum safety and simplicity.

### Benefits

✅ **Complete Isolation**
- Zero risk of overwriting backend/infrastructure files
- No need for branch protection or CODEOWNERS complexity
- Frontend team can work independently

✅ **Simpler Lovable Integration**
- Lovable connects to a dedicated frontend repo
- No need to configure directory restrictions
- Cleaner Git history

✅ **Independent Versioning**
- Frontend can version independently
- Different release cycles
- Clearer dependency management

✅ **Simpler CI/CD**
- Separate deployment pipelines
- Frontend deploys independently
- No risk of breaking backend builds

### Trade-offs

⚠️ **Shared Types**
- Need to publish `@credovo/shared-types` as an npm package
- Or use a monorepo tool (Nx, Turborepo, etc.)
- Or duplicate types (not recommended)

⚠️ **Coordination**
- Need to keep API contracts in sync
- Two repos to manage
- Slightly more complex setup

## Recommended Setup

### Option 1: Separate Repo with Published Package (Recommended)

**Structure:**
```
credovo-platform/          (Backend repo)
├── services/
├── infrastructure/
├── shared/
│   └── types/             → Publish as @credovo/shared-types
└── ...

credovo-webapp/            (Frontend repo - Lovable)
├── src/
├── package.json           → Uses @credovo/shared-types
└── ...
```

**Steps:**

1. **Publish Shared Types as NPM Package:**
   ```bash
   # In credovo-platform/shared/types/
   npm init -y
   # Configure package.json
   npm publish --access public
   # Or use GitHub Packages, npm private registry, etc.
   ```

2. **Create Frontend Repository:**
   **GitHub Repository**: `https://github.com/AmanorsElliot/credovo-webapp`
   
   Clone the repository:
   ```bash
   git clone https://github.com/AmanorsElliot/credovo-webapp.git
   cd credovo-webapp
   ```

3. **Connect Lovable:**
   - Connect to `credovo-frontend` repository
   - No restrictions needed - entire repo is frontend

4. **Install Shared Types:**
   ```bash
   # In credovo-frontend
   npm install @credovo/shared-types
   ```

### Option 2: Monorepo with Workspaces

**Structure:**
```
credovo-monorepo/
├── packages/
│   ├── frontend/         → Lovable connects here
│   ├── backend-services/
│   └── shared-types/
└── package.json          → Workspace configuration
```

**Pros:**
- Single repo
- Shared types without publishing
- Unified versioning

**Cons:**
- More complex setup
- Still need to protect backend from Lovable
- Monorepo tooling overhead

### Option 3: Git Submodule (Not Recommended)

**Structure:**
```
credovo-frontend/
├── src/
└── shared-types/         → Git submodule from credovo-platform
```

**Cons:**
- Complex to manage
- Submodule updates are manual
- Not ideal for active development

## Implementation Guide: Separate Repo

### Step 1: Publish Shared Types

**Option A: GitHub Packages (Recommended for Private)**

1. **Configure package.json in `shared/types/`:**
   ```json
   {
     "name": "@credovo/shared-types",
     "version": "1.0.0",
     "main": "dist/index.js",
     "types": "dist/index.d.ts",
     "publishConfig": {
       "registry": "https://npm.pkg.github.com"
     },
     "repository": {
       "type": "git",
       "url": "https://github.com/AmanorsElliot/credovo-platform.git"
     }
   }
   ```

2. **Publish:**
   ```bash
   npm publish --access public
   # Or for GitHub Packages:
   npm publish --registry=https://npm.pkg.github.com
   ```

**Option B: NPM Public/Private Registry**

1. **Publish to npm:**
   ```bash
   npm publish --access public
   ```

2. **Install in frontend:**
   ```bash
   npm install @credovo/shared-types
   ```

**Option C: Local Package (Development Only)**

For development, you can use `npm link`:
```bash
# In credovo-platform/shared/types/
npm link

# In credovo-frontend/
npm link @credovo/shared-types
```

### Step 2: Create Frontend Repository

```bash
# Create new repository
gh repo create credovo-frontend --public

# Or via GitHub web UI:
# https://github.com/new
# Name: credovo-frontend
# Description: Credovo Platform Frontend (Lovable)
```

### Step 3: Initialize Frontend Repository

```bash
# Clone the repository
git clone https://github.com/AmanorsElliot/credovo-webapp.git
cd credovo-webapp

# Copy frontend code from current repo
# (or let Lovable create it fresh)

# Create package.json
npm init -y

# Install shared types
npm install @credovo/shared-types

# Install other dependencies
npm install react react-dom
# ... other frontend deps
```

### Step 4: Connect Lovable

1. **In Lovable:**
   - Connect to `credovo-frontend` repository
   - No branch restrictions needed
   - No directory restrictions needed
   - Entire repo is frontend - completely safe!

2. **Configure Environment Variables:**
   - `REACT_APP_API_URL`: Backend orchestration service URL
   - `REACT_APP_LOVABLE_AUTH_URL`: Lovable auth URL

### Step 5: Update Backend CORS

Update `orchestration-service` CORS to allow the new frontend domain:

```typescript
// In orchestration-service/src/index.ts
const allowedOrigins = [
  'https://your-lovable-app.lovable.app',
  'http://localhost:3000', // Local dev
];
```

## Migration from Current Setup

If you already have code in `credovo-platform/frontend/`:

1. **Create new repo:**
   ```bash
   gh repo create credovo-frontend
   ```

2. **Copy frontend code:**
   ```bash
   cd credovo-frontend
   git clone https://github.com/AmanorsElliot/credovo-frontend.git
   # Copy files from credovo-platform/frontend/lovable-frontend/
   ```

3. **Update imports:**
   ```typescript
   // Old: import { KYCRequest } from '@credovo/shared-types'
   // New: import { KYCRequest } from '@credovo/shared-types'
   // (Same, but now from npm package)
   ```

4. **Remove from main repo:**
   ```bash
   # In credovo-platform
   git rm -r frontend/
   git commit -m "Move frontend to separate repository"
   ```

## Recommended Structure

```
credovo-platform/              (Backend - GitHub)
├── services/
│   ├── orchestration-service/
│   ├── kyc-kyb-service/
│   └── connector-service/
├── infrastructure/
│   └── terraform/
├── shared/
│   └── types/                 → Published as @credovo/shared-types
├── docs/
└── scripts/

credovo-webapp/                (Frontend - Lovable + GitHub)
├── src/
│   ├── components/
│   ├── pages/
│   └── utils/
├── package.json               → Uses @credovo/shared-types
└── .env                       → API URLs, etc.
```

## CI/CD for Separate Repos

### Backend (credovo-platform)
- Cloud Build triggers on push
- Deploys to Cloud Run
- Runs tests

### Frontend (credovo-frontend)
- Lovable handles deployment
- Or separate CI/CD for custom builds
- Deploys to hosting (Vercel, Netlify, etc.)

## Keeping Types in Sync

**When API changes:**

1. **Update types in `credovo-platform/shared/types/`**
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
   
   Or manually:
   ```bash
   cd credovo-platform/shared/types
   npm version patch  # or minor, major
   npm publish --registry=https://npm.pkg.github.com
   ```

3. **Update in frontend:**
   ```bash
   cd credovo-webapp
   npm update @credovo/shared-types
   ```

**Automation Option:**
- Use GitHub Actions to auto-publish on changes
- Use Dependabot to auto-update frontend

## Summary

**Separate Repository is Safer Because:**
- ✅ Zero risk of overwriting backend files
- ✅ Simpler Lovable integration
- ✅ Clear separation of concerns
- ✅ Independent versioning and deployment
- ✅ No need for branch protection complexity

**Recommended Approach:**
1. Publish `shared/types` as `@credovo/shared-types` npm package
2. Use `credovo-webapp` repository (already created)
3. Connect Lovable to `credovo-webapp` (entire repo is safe)
4. Install `@credovo/shared-types` in frontend

**This is the safest and cleanest approach!**

