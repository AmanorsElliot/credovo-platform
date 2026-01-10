# @credovo/shared-types

Shared TypeScript types for the Credovo platform, used by both backend services and the frontend webapp.

## Installation

### From GitHub Packages

```bash
npm install @credovo/shared-types --registry=https://npm.pkg.github.com
```

### From npm (if published publicly)

```bash
npm install @credovo/shared-types
```

## Usage

```typescript
import { KYCRequest, KYCResponse, KYBRequest, KYBResponse } from '@credovo/shared-types';

const kycRequest: KYCRequest = {
  applicationId: 'app-123',
  userId: 'user-456',
  type: 'individual',
  data: {
    firstName: 'John',
    lastName: 'Doe',
    dateOfBirth: '1990-01-01'
  }
};
```

## Types Included

- `Application` - Application data structure
- `ApplicationStatus` - Application status enum
- `KYCRequest` / `KYCResponse` - KYC verification types
- `KYBRequest` / `KYBResponse` - KYB verification types
- `ConnectorRequest` / `ConnectorResponse` - Connector service types
- `Address` - Address structure
- `CheckResult` - Verification check results
- `ApiError` - API error structure

## Publishing

This package is published from the `credovo-platform` repository:

```bash
cd shared/types
npm install
npm run build
npm publish --registry=https://npm.pkg.github.com
```

Or use the script:

```powershell
.\scripts\publish-shared-types.ps1
```

## Versioning

Follows semantic versioning. Update version in `package.json` before publishing.

