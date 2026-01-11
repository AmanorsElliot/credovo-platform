# Server-Side Input Validation Implementation

## Overview

Comprehensive server-side input validation has been implemented across all API endpoints using **Zod** validation schemas. This addresses the security finding that input validation was relying solely on client-side checks.

## What Was Implemented

### 1. Validation Schemas (`shared/types/validation.ts`)

Created Zod schemas for all request types:

- **KYCRequestSchema**: Validates KYC initiation requests
  - Validates applicationId, userId, type (individual/company)
  - Validates data fields (firstName, lastName, dateOfBirth, email, country, address, companyNumber, companyName)
  - Enforces type-specific requirements (individual requires firstName/lastName, company requires companyNumber/companyName)

- **KYBRequestSchema**: Validates KYB verification requests
  - Validates applicationId, companyNumber, companyName, country, email

- **CompanySearchQuerySchema**: Validates company search queries
  - Validates query (min 2 chars, max 200)
  - Validates limit (1-50, default 10)

- **BankLinkRequestSchema**: Validates Plaid link token requests
  - Validates applicationId, userId, products array, redirectUri, webhook

- **BankLinkExchangeRequestSchema**: Validates token exchange requests
  - Validates applicationId, userId, publicToken

- **AccountBalanceRequestSchema**: Validates account balance requests
  - Validates applicationId, userId, accessToken, accountIds array

- **TransactionRequestSchema**: Validates transaction requests
  - Validates applicationId, userId, accessToken, startDate, endDate, count
  - Enforces date range validation (start <= end, max 2 years)

- **AuthTokenRequestSchema**: Validates auth token exchange requests
  - Validates userId, email, name

- **ConnectorRequestSchema**: Validates connector service requests
  - Validates provider, endpoint, method, headers, body

- **ApplicationIdParamSchema**: Validates application ID URL parameters

### 2. Validation Middleware (`shared/types/validation-middleware.ts`)

Created reusable validation middleware:

- **validateRequest()**: Validates body, query, and/or params
- **validateBody()**: Validates request body only
- **validateQuery()**: Validates query parameters only
- **validateParams()**: Validates URL parameters only

Features:
- Returns user-friendly error messages with field paths
- Returns 400 Bad Request with detailed validation errors
- Replaces request data with validated (and potentially transformed) data

### 3. Applied to All Routes

Validation has been applied to:

#### Orchestration Service
- ✅ `POST /api/v1/applications/:applicationId/kyc/initiate`
- ✅ `GET /api/v1/applications/:applicationId/kyc/status`
- ✅ `POST /api/v1/applications/:applicationId/kyb/verify`
- ✅ `GET /api/v1/applications/:applicationId/kyb/status`
- ✅ `POST /api/v1/applications/:applicationId/banking/link-token`
- ✅ `POST /api/v1/applications/:applicationId/banking/exchange-token`
- ✅ `POST /api/v1/applications/:applicationId/banking/accounts/balance`
- ✅ `POST /api/v1/applications/:applicationId/banking/transactions`
- ✅ `GET /api/v1/companies/search`
- ✅ `POST /api/v1/auth/token`

#### KYC/KYB Service
- ✅ `POST /api/v1/kyc/initiate`
- ✅ `GET /api/v1/kyc/status/:applicationId`
- ✅ `POST /api/v1/kyb/verify`
- ✅ `GET /api/v1/kyb/status/:applicationId`

#### Company Search Service
- ✅ `GET /api/v1/companies/search`

#### Open Banking Service
- ✅ `POST /api/v1/banking/link-token`
- ✅ `POST /api/v1/banking/exchange-token`
- ✅ `POST /api/v1/banking/accounts/balance`
- ✅ `POST /api/v1/banking/transactions`

## Validation Rules

### String Validation
- **Length**: Min/max length enforced
- **Format**: Email format, date format (YYYY-MM-DD), ISO country codes (2-letter uppercase)
- **Required**: Required fields validated

### Number Validation
- **Type**: Must be integer
- **Range**: Min/max values enforced
- **Coercion**: Query parameters coerced to numbers

### Enum Validation
- **KYC Type**: Must be 'individual' or 'company'
- **HTTP Method**: Must be GET, POST, PUT, or DELETE
- **Plaid Products**: Must be valid Plaid product types

### Date Validation
- **Format**: Must be YYYY-MM-DD
- **Range**: Start date must be <= end date
- **Max Range**: Date range cannot exceed 2 years

### Custom Validation
- **Type-Specific**: Individual KYC requires firstName/lastName, Company KYC requires companyNumber/companyName
- **Date Range**: Transaction date range validation

## Error Response Format

When validation fails, the API returns:

```json
{
  "error": "Validation Error",
  "message": "Invalid request body" | "Invalid query parameters" | "Invalid URL parameters",
  "details": [
    {
      "path": "data.firstName",
      "message": "First name is required"
    },
    {
      "path": "data.email",
      "message": "Invalid email format"
    }
  ]
}
```

## Security Benefits

1. **Prevents Bypass**: Client-side validation can be bypassed; server-side validation cannot
2. **Type Safety**: Ensures data types match expected formats
3. **Input Sanitization**: Validates and sanitizes all inputs before processing
4. **Error Messages**: Provides clear error messages without exposing internal details
5. **Defense in Depth**: Works alongside client-side validation for better UX

## Testing

To test validation:

```bash
# Test invalid KYC request (missing required fields)
curl -X POST https://api.example.com/api/v1/applications/123/kyc/initiate \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"type": "individual"}'
# Expected: 400 Bad Request with validation errors

# Test invalid email format
curl -X POST https://api.example.com/api/v1/applications/123/kyc/initiate \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"type": "individual", "data": {"email": "invalid-email"}}'
# Expected: 400 Bad Request - "Invalid email format"

# Test invalid date range
curl -X POST https://api.example.com/api/v1/applications/123/banking/transactions \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"accessToken": "token", "startDate": "2024-01-01", "endDate": "2023-12-31"}'
# Expected: 400 Bad Request - "Start date must be before or equal to end date"
```

## Dependencies

- **zod**: ^3.22.4 - Schema validation library
- **@types/express**: ^4.17.21 - Express type definitions
- **@types/node**: ^20.10.0 - Node.js type definitions

## Next Steps

1. ✅ **Completed**: Basic validation implemented
2. ⚠️ **Optional**: Add input sanitization (XSS prevention)
3. ⚠️ **Optional**: Add rate limiting per user/IP
4. ⚠️ **Optional**: Add request size limits
5. ⚠️ **Optional**: Add file upload validation (if implementing file uploads)

## Notes

- Validation runs **before** route handlers, ensuring invalid data never reaches business logic
- Validated data replaces original request data, ensuring only clean data is processed
- Error messages are user-friendly and don't expose internal implementation details
- All validation schemas are exported from `@credovo/shared-types/validation` for reuse
