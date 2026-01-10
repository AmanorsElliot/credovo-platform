# Setting Up Shared Types in Lovable

This guide shows you how to use the Credovo shared types in your Lovable project.

## Package Contents

The `@amanorselliot/shared-types` package contains TypeScript type definitions for:

- **Application** - Application data structure and status enum
- **KYCRequest / KYCResponse** - KYC verification types
- **KYBRequest / KYBResponse** - KYB verification types  
- **ConnectorRequest / ConnectorResponse** - Connector service types
- **Address** - Address structure
- **CheckResult** - Verification check results
- **ApiError** - API error structure

**Total**: ~115 lines of pure TypeScript type definitions (no runtime code)

## Recommended Approach: Publish to Public npm ⭐

**Best Solution**: Publish to public npm (npmjs.com) for automatic updates and version management.

### Why Public npm Instead of GitHub Packages?

✅ **No authentication needed** - Works in Lovable without tokens  
✅ **No registry configuration** - Standard npm workflow  
✅ **Version management** - Semantic versioning  
✅ **Easy updates** - `npm update` command  
✅ **Works everywhere** - Lovable, CI/CD, local dev

### Alternative: Copy Types Directly

If you prefer not to use npm, you can copy types directly (but requires manual syncing).

## Setup: Public npm Package (Recommended)

### Step 1: Publish to npm

From `credovo-platform`:

```powershell
# Login to npm (one-time)
npm login

# Publish
.\scripts\publish-to-npm.ps1
```

### Step 2: Install in Lovable

In your Lovable project (`credovo-webapp`):

```bash
npm install @amanorselliot/shared-types
```

**That's it!** No registry configuration, no tokens needed.

### Step 3: Update When Types Change

```powershell
# In credovo-platform
cd shared/types
npm version patch  # Bumps version
cd ../..
.\scripts\publish-to-npm.ps1

# In credovo-webapp
npm update @amanorselliot/shared-types
```

## Alternative: Copy Types Directly

If you prefer not to use npm:

#### Option A: Use Helper Script

```powershell
# From credovo-platform directory
.\scripts\copy-shared-types-to-webapp.ps1
```

This will:
- Copy `shared/types/index.ts` → `credovo-webapp/src/types/shared-types.ts`
- Create the `src/types/` directory if needed
- Show you usage examples

#### Option B: Manual Copy

1. **Copy the types file:**
   ```bash
   # From credovo-platform
   cp shared/types/index.ts ../credovo-webapp/src/types/shared-types.ts
   ```

2. **Or create manually in Lovable:**
   - Create `src/types/shared-types.ts` in your Lovable project
   - Copy the contents from: https://github.com/AmanorsElliot/credovo-platform/blob/main/shared/types/index.ts

### Usage in Your Code

After copying, import from the local file:

```typescript
// Instead of: import { KYCRequest } from '@amanorselliot/shared-types'
import { KYCRequest, KYCResponse, KYBRequest, KYBResponse } from './types/shared-types';
// Or with path alias:
import { KYCRequest, KYCResponse } from '@/types/shared-types';
```

### Example Usage

```typescript
import { KYCRequest, KYCResponse, KYBRequest, KYBResponse } from './types/shared-types';

// KYC Example
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

// KYB Example
const kybRequest: KYBRequest = {
  applicationId: 'app-123',
  companyNumber: '12345678',
  companyName: 'Example Ltd',
  country: 'GB',
  email: 'contact@example.com'
};
```

## Keeping Types in Sync

When types change in `credovo-platform`:

1. **Update types in backend:**
   ```bash
   cd credovo-platform
   # Edit shared/types/index.ts
   ```

2. **Copy updated types to webapp:**
   ```powershell
   .\scripts\copy-shared-types-to-webapp.ps1
   ```

3. **Or manually:**
   - Copy `shared/types/index.ts` → `credovo-webapp/src/types/shared-types.ts`
   - Commit changes to `credovo-webapp`

## Why Not GitHub Packages?

Even though the package is public on GitHub Packages, Lovable's build system:
- ❌ Doesn't support configuring npm authentication tokens
- ❌ May not be able to access GitHub Packages registry
- ❌ Requires `.npmrc` configuration that may not work in Lovable

**Solution**: Publish to public npm (npmjs.com) instead, which:
- ✅ Works in Lovable without any configuration
- ✅ Standard npm workflow
- ✅ No authentication needed

## Type Definitions Reference

Here's what's included in the package:

### Application Types
```typescript
interface Application {
  id: string;
  userId: string;
  status: ApplicationStatus;
  createdAt: Date;
  updatedAt: Date;
  data: Record<string, any>;
}

enum ApplicationStatus {
  PENDING = 'pending',
  IN_PROGRESS = 'in_progress',
  COMPLETED = 'completed',
  REJECTED = 'rejected',
  FAILED = 'failed'
}
```

### KYC Types
```typescript
interface KYCRequest {
  applicationId: string;
  userId: string;
  type: 'individual' | 'company';
  data: {
    firstName?: string;
    lastName?: string;
    dateOfBirth?: string;
    address?: Address;
    companyNumber?: string;
    companyName?: string;
  };
}

interface KYCResponse {
  applicationId: string;
  status: 'pending' | 'approved' | 'rejected' | 'requires_review';
  provider: string;
  result?: {
    score?: number;
    checks?: CheckResult[];
    metadata?: Record<string, any>;
    aml?: any;
  };
  timestamp: Date;
}
```

### KYB Types
```typescript
interface KYBRequest {
  applicationId: string;
  companyNumber: string;
  companyName?: string;
  country?: string;
  email?: string;
}

interface KYBResponse {
  applicationId: string;
  companyNumber: string;
  status: 'verified' | 'not_found' | 'pending' | 'error';
  data?: {
    companyName?: string;
    status?: string;
    incorporationDate?: string;
    address?: Address;
    officers?: any[];
  };
  aml?: any;
  timestamp: Date;
}
```

### Supporting Types
```typescript
interface Address {
  line1: string;
  line2?: string;
  city: string;
  postcode: string;
  country: string;
}

interface CheckResult {
  type: string;
  status: 'pass' | 'fail' | 'pending';
  message?: string;
}

interface ConnectorRequest {
  provider: string;
  endpoint: string;
  method: 'GET' | 'POST' | 'PUT' | 'DELETE';
  headers?: Record<string, string>;
  body?: any;
  retry?: boolean;
}

interface ConnectorResponse<T = any> {
  success: boolean;
  data?: T;
  error?: {
    code: string;
    message: string;
    details?: any;
  };
  metadata?: {
    provider: string;
    latency: number;
    retries?: number;
  };
}
```

## Summary

**Recommended**: Publish to public npm and install normally ⭐

**Why**: 
- ✅ Works in Lovable without any configuration
- ✅ No authentication or registry setup needed
- ✅ Version management with semantic versioning
- ✅ Easy updates with `npm update`
- ✅ Standard npm workflow

**Workflow**:
1. Publish: `.\scripts\publish-to-npm.ps1`
2. Install: `npm install @amanorselliot/shared-types`
3. Update: `npm update @amanorselliot/shared-types`

**Alternative**: Copy types directly if you prefer (but requires manual syncing)

For automatic updates and version management, npm is the best solution!

