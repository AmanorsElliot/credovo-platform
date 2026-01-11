# Credovo Digital Mortgage Lending Platform

Credovo is a fully automated secured and unsecured commercial finance platform that enables applicants to complete a full mortgage agreement in under 24 hours.

## Architecture

This platform is built as a microservices architecture deployed on Google Cloud Platform:

- **Backend**: Cloud Run microservices
- **Data Layer**: GCS Data Lake, BigQuery, Cloud SQL
- **Infrastructure**: Terraform for IaC, Cloud Build for CI/CD

## Repository Structure

```
credovo-platform/
├── .github/workflows/     # CI/testing workflows
├── services/              # Microservices
│   ├── kyc-kyb-service/   # Identity and company verification
│   ├── connector-service/ # Vendor integration abstraction layer
│   ├── orchestration-service/ # API gateway and request routing
│   ├── company-search-service/ # Company search and autocomplete
│   └── open-banking-service/ # Open banking and financial data
├── infrastructure/        # Terraform configurations
├── shared/                # Shared libraries
└── docs/                  # Documentation
```

## Getting Started

See individual service READMEs for setup instructions.

## Services

- **Orchestration Service**: API gateway and request routing
- **KYC/KYB Service**: Identity and company verification (Shufti Pro, SumSub)
- **Company Search Service**: Company search and autocomplete (The Companies API)
- **Open Banking Service**: Financial data and income verification (Plaid)
- **Connector Service**: Vendor integration abstraction layer with circuit breakers and rate limiting

## Documentation

Comprehensive documentation is available in the [`docs/`](docs/) directory:

- **[Quick Start](docs/QUICK_START.md)** - Get started quickly
- **[Architecture](docs/architecture.md)** - System architecture overview
- **[Service Interactions](docs/SERVICE_INTERACTIONS.md)** - How services communicate
- **[Deployment](docs/deployment.md)** - Deployment instructions
- **[Monitoring](docs/MONITORING_SETUP.md)** - Monitoring and alerting setup
- **[Shufti Pro Integration](docs/SHUFTI_PRO_API_REQUIREMENTS.md)** - KYC/KYB provider integration

## CI/CD

This project uses **Cloud Build** for automated builds and deployments:
- Parallel builds for all services (faster deployment)
- Automatic builds on push to GitHub
- Docker image builds and pushes to Artifact Registry
- Automatic deployment to Cloud Run

See [Cloud Build Setup](docs/CLOUD_BUILD_GITHUB_SETUP.md) for details.

## Testing

Comprehensive end-to-end testing is available:
- KYC/KYB verification flows
- Webhook processing
- Data lake storage
- Status checks and error handling

See [Testing Guide](docs/TESTING_GUIDE.md) for instructions.

## License

Proprietary
