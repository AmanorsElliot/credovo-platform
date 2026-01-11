# Integrations Guide

This guide covers all external service integrations in the Credovo platform.

## Plaid (Open Banking)

### Overview
Plaid integration provides open banking functionality including account verification, transaction history, and income verification.

### Documentation
- **[Plaid Integration Guide](PLAID_INTEGRATION.md)** - Complete API documentation and usage
- **[Plaid Credentials Setup](PLAID_CREDENTIALS_SETUP.md)** - Credential configuration

### Quick Start
1. Credentials are configured in GCP Secret Manager
2. Service uses sandbox environment by default (`PLAID_ENV=sandbox`)
3. See [PLAID_INTEGRATION.md](PLAID_INTEGRATION.md) for API endpoints

### Production Access Status
**⚠️ Limited Production Access**: Current production credentials can only access institutions that don't use OAuth. OAuth-only institutions are not available until full production access is granted.

## Shufti Pro (KYC/KYB)

### Overview
Shufti Pro is the primary KYC/KYB verification provider, supporting 240+ countries and 150+ languages.

### Documentation
- **[Shufti Pro API Requirements](SHUFTI_PRO_API_REQUIREMENTS.md)** - API integration details
- **[Webhook Setup](WEBHOOK_SETUP.md)** - Webhook endpoint configuration
- **[Webhook Registration](WEBHOOK_REGISTRATION_GUIDE.md)** - Registering webhooks with Shufti Pro

### Quick Start
1. Credentials stored in Secret Manager (`shufti-pro-client-id`, `shufti-pro-secret-key`)
2. Webhook endpoint: `/api/v1/webhooks/shufti-pro`
3. See [SHUFTI_PRO_API_REQUIREMENTS.md](SHUFTI_PRO_API_REQUIREMENTS.md) for details

## Clearbit (Company Search & Autocomplete)

### ⚠️ Important: HubSpot Account Required

**Status**: Clearbit has been acquired by HubSpot and now requires a HubSpot account to access their API. This may require a paid HubSpot plan depending on your needs.

### Overview
Clearbit provides company search with autocomplete functionality and company enrichment data.

### Features
- **Company Search**: Real-time autocomplete for company names
- **Company Enrichment**: Detailed company data (employees, revenue, industry, etc.)
- **Domain Lookup**: Find companies by domain name
- **Global Coverage**: US, UK, EU, and other countries

### Documentation
- **Clearbit API Docs**: https://clearbit.com/docs#enrichment-api
- **HubSpot Integration**: https://www.hubspot.com/company-news/hubspot-completes-acquisition-of-b2b-intelligence-leader-clearbit

### Quick Start

**⚠️ Important**: Clearbit is not available as a standalone integration in the HubSpot marketplace, and direct Clearbit login is no longer available. API access may require contacting HubSpot/Clearbit support.

### Setup:
1. **Get Clearbit API Key**:
   - Log into https://clearbit.com/ directly (not through HubSpot marketplace)
   - Navigate to **Settings** → **API Keys**
   - Create or copy your API key
2. **Store API key**: Use `scripts/configure-clearbit-secret.ps1` or see [Clearbit HubSpot Setup Guide](CLEARBIT_HUBSPOT_SETUP.md)
3. **Configure service**: Set `COMPANY_SEARCH_PROVIDER=clearbit` in company-search-service
4. Use endpoint: `GET /api/v1/companies/search?query=company+name`

**📖 Detailed Setup**: See [CLEARBIT_HUBSPOT_SETUP.md](CLEARBIT_HUBSPOT_SETUP.md) for step-by-step instructions

### API Endpoints
- `GET /api/v1/companies/search?query=name&limit=10` - Company search with autocomplete
- `GET /api/v1/companies/enrich?domain=example.com` - Company enrichment by domain

### Alternatives
- **Clearbit**: Company search and enrichment (requires HubSpot account)
- **Companies House API**: UK company data (already integrated)

---

## The Companies API ✅ (Default Provider)

**Status**: ✅ **Active and configured as default provider**

### Overview
The Companies API provides UK-focused company search with autocomplete functionality. It's a standalone API that doesn't require HubSpot or other third-party accounts.

### Features
- **Company Search**: Real-time autocomplete for UK company names
- **Company Lookup**: Find companies by name or company number
- **UK Coverage**: Comprehensive UK company database
- **Standalone API**: No HubSpot or third-party account required

### Documentation
- **The Companies API Docs**: https://www.thecompaniesapi.com/
- **API Endpoints**: https://www.thecompaniesapi.com/docs

### Quick Start

**✅ Already Configured**: The Companies API is set as the default provider for company search.

1. **API Keys** (already configured):
   - Production API Key: Stored in GCP Secret Manager as `companies-api-api-key`
   - Sandbox API Key: Available for testing

2. **Update Secret** (if needed):
   ```powershell
   .\scripts\configure-companies-api-secret.ps1 -Environment production
   ```

3. **Use endpoint**: `GET /api/v1/companies/search?query=company+name`

### API Endpoints
- `GET /api/v1/companies/search?query=name&limit=10` - Company search with autocomplete
- `GET /api/v1/companies/company?name=company+name` - Company lookup by name
- `GET /api/v1/companies/company?number=12345678` - Company lookup by number

### Configuration
- **Default Provider**: The Companies API is the default (`COMPANY_SEARCH_PROVIDER=companies-api`)
- **Environment Variable**: `COMPANIES_API_API_KEY` (automatically loaded from Secret Manager)
- **Switch to Clearbit**: Set `COMPANY_SEARCH_PROVIDER=clearbit` in company-search-service (requires Clearbit API key)

## Credentials Management

All credentials are stored in GCP Secret Manager. See [CREDENTIALS.md](CREDENTIALS.md) for details.
