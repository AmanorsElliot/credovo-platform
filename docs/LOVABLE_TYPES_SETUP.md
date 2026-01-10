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

## Recommended Approach: Copy Types Directly ⭐

Since the package contains only TypeScript types (no runtime code), the cleanest approach is to copy them directly into your Lovable project.

### Why Copy Instead of npm Package?

✅ **No registry configuration needed** - Works immediately in Lovable  
✅ **No authentication required** - No GitHub tokens needed  
✅ **Types visible in codebase** - Easy to see and modify  
✅ **No build-time dependencies** - Faster builds  
✅ **Simpler for type-only packages** - Common pattern for shared types

### Setup Steps

#### Option A: Use Helper Script (Recommended)

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

## Alternative: Try npm Installation

If you prefer to use the npm package (even though copying is simpler):

### Step 1: Configure .npmrc

Create `.npmrc` in `credovo-webapp`:

```ini
@amanorselliot:registry=https://npm.pkg.github.com
```

**Note**: For public packages, you typically don't need an auth token, but Lovable's build environment might still have issues.

### Step 2: Install

```bash
npm install @amanorselliot/shared-types
```

### Step 3: Use

```typescript
import { KYCRequest, KYCResponse } from '@amanorselliot/shared-types';
```

**Warning**: This may fail in Lovable's build environment if it can't access GitHub Packages registry.

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

**Recommended**: Copy types directly to `src/types/shared-types.ts`

**Why**: 
- ✅ Works immediately in Lovable
- ✅ No registry configuration
- ✅ No authentication needed
- ✅ Types visible in codebase
- ✅ Common pattern for type-only packages

**When to use npm package**:
- If you need version management
- If types include runtime code (not the case here)
- If you want automatic updates (but you'll still need to sync manually)

For a type-only package like this, copying is the simplest and most reliable approach!

