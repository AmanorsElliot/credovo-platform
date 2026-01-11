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

## Credentials Management

All credentials are stored in GCP Secret Manager. See [CREDENTIALS.md](CREDENTIALS.md) for details.
