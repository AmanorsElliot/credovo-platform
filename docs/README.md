# Documentation

This directory contains documentation for the Credovo platform.

## Essential Documentation

### Getting Started
- **[Quick Start Guide](QUICK_START.md)** - Get up and running quickly
- **[Deployment Guide](deployment.md)** - Complete deployment instructions
- **[Terraform Setup](TERRAFORM_SETUP.md)** - Infrastructure as Code setup

### Architecture & Design
- **[Architecture Overview](architecture.md)** - System architecture and components
- **[Service Interactions](SERVICE_INTERACTIONS.md)** - How services communicate
- **[Authentication Guide](AUTHENTICATION.md)** - Authentication patterns and setup

### Integrations
- **[Integrations Guide](INTEGRATIONS.md)** - All external service integrations (Plaid, Shufti Pro)
- **[Plaid Integration](PLAID_INTEGRATION.md)** - Open banking integration
- **[Plaid Credentials](PLAID_CREDENTIALS_SETUP.md)** - Plaid credential setup
- **[Shufti Pro API](SHUFTI_PRO_API_REQUIREMENTS.md)** - KYC/KYB provider integration
- **[Webhook Setup](WEBHOOK_SETUP.md)** - Webhook endpoint configuration
- **[Credentials Management](CREDENTIALS.md)** - Credential storage and management

### Operations
- **[Operations Guide](OPERATIONS.md)** - Monitoring, testing, troubleshooting
- **[Monitoring Setup](MONITORING_SETUP.md)** - Comprehensive monitoring and alerting
- **[Testing Guide](TESTING_GUIDE.md)** - End-to-end testing instructions
- **[Cloud Build Troubleshooting](CLOUD_BUILD_TROUBLESHOOTING.md)** - Common build issues

### CI/CD
- **[Cloud Build Setup](CLOUD_BUILD_GITHUB_SETUP.md)** - Automated builds and deployments

## Documentation Structure

```
docs/
├── README.md                    # This file - documentation index
├── QUICK_START.md              # Quick start guide
├── deployment.md               # Deployment instructions
├── TERRAFORM_SETUP.md          # Terraform configuration
├── architecture.md             # System architecture
├── SERVICE_INTERACTIONS.md     # Service communication patterns
├── AUTHENTICATION.md           # Authentication setup
├── CLOUD_BUILD_GITHUB_SETUP.md # CI/CD setup
├── MONITORING_SETUP.md         # Monitoring and alerting setup
├── monitoring.md               # Monitoring concepts and queries
├── SHUFTI_PRO_API_REQUIREMENTS.md # KYC/KYB provider integration
├── WEBHOOK_SETUP.md            # Webhook endpoint configuration
├── WEBHOOK_REGISTRATION_GUIDE.md # Registering webhooks
├── CREDENTIALS.md              # Credential management
├── TESTING_GUIDE.md            # End-to-end testing guide
├── TEST_AUTH_TOKEN.md           # Authentication tokens for testing
├── CLOUD_BUILD_TROUBLESHOOTING.md # Build troubleshooting
├── NEXT_STEPS.md               # Current status and next actions
└── MULTI_REGION_STRATEGY.md    # Multi-region deployment strategy
```

## Quick Links

- **Deploy Infrastructure**: See [deployment.md](deployment.md)
- **Set Up CI/CD**: See [CLOUD_BUILD_GITHUB_SETUP.md](CLOUD_BUILD_GITHUB_SETUP.md)
- **Understand Architecture**: See [architecture.md](architecture.md) and [SERVICE_INTERACTIONS.md](SERVICE_INTERACTIONS.md)
- **Configure Authentication**: See [AUTHENTICATION.md](AUTHENTICATION.md)

