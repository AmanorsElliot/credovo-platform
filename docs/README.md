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

### CI/CD
- **[Cloud Build Setup](CLOUD_BUILD_GITHUB_SETUP.md)** - Automated builds and deployments

### Integration
- **[Shufti Pro API Requirements](SHUFTI_PRO_API_REQUIREMENTS.md)** - KYC/KYB provider integration
- **[Webhook Setup](WEBHOOK_SETUP.md)** - Webhook endpoint configuration
- **[Webhook Registration](WEBHOOK_REGISTRATION_GUIDE.md)** - Registering webhooks with Shufti Pro
- **[Credentials Management](CREDENTIALS.md)** - Credential storage and management
- **[Lovable Separate Repo](LOVABLE_SEPARATE_REPO.md)** - ⭐ **Recommended**: Separate repository strategy (`credovo-webapp`)
- **[Credovo Webapp Setup](CREDOVO_WEBAPP_SETUP.md)** - Complete setup guide for `credovo-webapp` repository
- **[Automated Types Sync](AUTOMATED_TYPES_SYNC.md)** - Keeping shared types in sync between repos
- **[Lovable Types Setup](LOVABLE_TYPES_SETUP.md)** - Setting up shared types in Lovable

### Operations
- **[Monitoring Setup](MONITORING_SETUP.md)** - Comprehensive monitoring and alerting
- **[Monitoring Overview](monitoring.md)** - Monitoring concepts and log queries

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
├── NEXT_STEPS.md               # Current status and next actions
└── MULTI_REGION_STRATEGY.md    # Multi-region deployment strategy
```

## Quick Links

- **Deploy Infrastructure**: See [deployment.md](deployment.md)
- **Set Up CI/CD**: See [CLOUD_BUILD_GITHUB_SETUP.md](CLOUD_BUILD_GITHUB_SETUP.md)
- **Understand Architecture**: See [architecture.md](architecture.md) and [SERVICE_INTERACTIONS.md](SERVICE_INTERACTIONS.md)
- **Configure Authentication**: See [AUTHENTICATION.md](AUTHENTICATION.md)

