# Integration Status - Credovo Platform

**Last Updated**: January 2025

## Overview

This document provides a comprehensive status of all integrations in the Credovo platform.

## Service Status

| Service | Status | URL | Health Endpoint |
|---------|--------|-----|----------------|
| Orchestration Service | ✅ Deployed | `https://orchestration-service-saz24fo3sa-ew.a.run.app` | `/health` |
| Company Search Service | ✅ Deployed | `https://company-search-service-saz24fo3sa-ew.a.run.app` | `/health` |
| Open Banking Service | ✅ Deployed | `https://open-banking-service-saz24fo3sa-ew.a.run.app` | `/health` |
| Connector Service | ✅ Deployed | `https://connector-service-saz24fo3sa-ew.a.run.app` | `/health` |
| KYC/KYB Service | ✅ Deployed | `https://kyc-kyb-service-saz24fo3sa-ew.a.run.app` | `/health` |

## External Integrations

### ✅ The Companies API (Company Search)

**Status**: ✅ **Active and Configured**

- **Provider**: The Companies API
- **Purpose**: Company search and autocomplete
- **API Key**: Configured in GCP Secret Manager (`companies-api-api-key`)
- **Endpoints**:
  - `GET /api/v1/companies/search?query=name&limit=10` - Company search
  - `GET /api/v1/companies/enrich?domain=example.com` - Company enrichment (not supported)
- **Documentation**: https://www.thecompaniesapi.com/
- **Service**: `company-search-service`
- **Connector**: `companies-api` (via `connector-service`)

**Testing**:
```powershell
# Test company search
$token = gcloud auth print-identity-token
$headers = @{ "Authorization" = "Bearer $token" }
Invoke-WebRequest -Uri "https://orchestration-service-saz24fo3sa-ew.a.run.app/api/v1/companies/search?query=test&limit=5" -Headers $headers
```

### ✅ Plaid (Open Banking)

**Status**: ✅ **Active and Configured**

- **Provider**: Plaid
- **Purpose**: Open banking, account verification, transaction history, income verification
- **Credentials**: Configured in GCP Secret Manager
  - `plaid-client-id`
  - `plaid-secret-key` (production)
  - `plaid-sandbox-secret-key` (sandbox)
- **Environment**: Sandbox (default), Production (limited access)
- **Endpoints**:
  - `POST /api/v1/applications/:applicationId/banking/link-token` - Create Link token
  - `POST /api/v1/applications/:applicationId/banking/exchange-token` - Exchange public token
  - `POST /api/v1/applications/:applicationId/banking/accounts/balance` - Get balances
  - `POST /api/v1/applications/:applicationId/banking/transactions` - Get transactions
  - `POST /api/v1/applications/:applicationId/banking/income/verify` - Income verification
- **Documentation**: [PLAID_INTEGRATION.md](PLAID_INTEGRATION.md)
- **Service**: `open-banking-service`
- **Connector**: `plaid` (via `connector-service`)

**⚠️ Production Access Note**: Current production credentials have limited access - can only access institutions that don't use OAuth. OAuth-only institutions require full production access.

### ✅ Shufti Pro (KYC/KYB)

**Status**: ✅ **Active and Configured**

- **Provider**: Shufti Pro (Primary), SumSub (Fallback)
- **Purpose**: Identity verification (KYC) and business verification (KYB)
- **Coverage**: 240+ countries, 150+ languages
- **Credentials**: Configured in GCP Secret Manager
  - `shufti-pro-client-id`
  - `shufti-pro-secret-key`
- **Features**:
  - Document verification
  - Biometric verification
  - AML screening
  - Watchlist checks
- **Endpoints**:
  - `POST /api/v1/applications/:applicationId/kyc/initiate` - Initiate KYC
  - `GET /api/v1/applications/:applicationId/kyc/status` - Check KYC status
  - `POST /api/v1/applications/:applicationId/kyb/initiate` - Initiate KYB
  - `GET /api/v1/applications/:applicationId/kyb/status` - Check KYB status
- **Webhooks**: `/api/v1/webhooks/shufti-pro`
- **Documentation**: [SHUFTI_PRO_API_REQUIREMENTS.md](SHUFTI_PRO_API_REQUIREMENTS.md)
- **Service**: `kyc-kyb-service`
- **Connector**: `shufti-pro`, `sumsub` (via `connector-service`)

### ✅ Companies House (UK Company Verification)

**Status**: ✅ **Active and Configured**

- **Provider**: Companies House API (UK Government)
- **Purpose**: UK company verification and data
- **API Key**: Configured in GCP Secret Manager (`companies-house-api-key`)
- **Documentation**: https://developer.company-information.service.gov.uk/
- **Service**: `connector-service`
- **Connector**: `companies-house` (via `connector-service`)

## Authentication & Access

### Service-to-Service Authentication

- **Method**: GCP Service Accounts + Identity Tokens
- **Fallback**: JWT tokens using `SERVICE_JWT_SECRET`
- **Configuration**: Automatic via Cloud Run service accounts

### Public Access

**Current Status**: Services require authentication by default.

**To Enable Public Access** (if needed):
1. Update `infrastructure/terraform/cloud-run.tf`
2. Uncomment IAM member resources for `allUsers`
3. Apply Terraform changes

**Note**: Organization policies may restrict public access (`allUsers`).

## Testing

### Quick Test

```powershell
# Test all integrations
.\scripts\test-integrations.ps1
```

### Manual Testing

1. **Get Identity Token**:
   ```powershell
   $token = gcloud auth print-identity-token
   ```

2. **Test Company Search**:
   ```powershell
   $headers = @{ "Authorization" = "Bearer $token" }
   Invoke-WebRequest -Uri "https://orchestration-service-saz24fo3sa-ew.a.run.app/api/v1/companies/search?query=test" -Headers $headers
   ```

3. **Test Health Endpoints**:
   ```powershell
   $headers = @{ "Authorization" = "Bearer $token" }
   Invoke-WebRequest -Uri "https://orchestration-service-saz24fo3sa-ew.a.run.app/health" -Headers $headers
   ```

## Known Issues

1. **Service Access**: Services require authentication - health endpoints return 403 Forbidden for unauthenticated requests
   - **Workaround**: Use `gcloud auth print-identity-token` to get a token for testing
   - **Solution**: Make health endpoints public or use service account authentication

2. **Plaid Production Access**: Limited to non-OAuth institutions
   - **Status**: Expected - will be resolved when full production access is granted

## Next Steps

1. ✅ All services deployed and running
2. ✅ All integrations configured
3. ⚠️ Test integrations with proper authentication
4. ⚠️ Consider making health endpoints public for monitoring
5. ⚠️ Complete end-to-end testing with real API calls

## Documentation

- [Integrations Guide](INTEGRATIONS.md) - Detailed integration documentation
- [Testing Guide](TESTING_GUIDE.md) - Comprehensive testing instructions
- [Deployment Guide](deployment.md) - Deployment and configuration
- [Architecture](architecture.md) - System architecture overview
