# Credovo Digital Mortgage Lending Platform

Credovo is a fully automated secured and unsecured commercial finance platform that enables applicants to complete a full mortgage agreement in under 24 hours.

## Architecture

This platform is built as a microservices architecture deployed on Google Cloud Platform:

- **Frontend**: Lovable frontend with Lovable Cloud authentication
- **Backend**: Cloud Run microservices
- **Data Layer**: GCS Data Lake, BigQuery, Cloud SQL
- **Infrastructure**: Terraform for IaC, GitHub Actions for CI/CD

## Repository Structure

```
credovo-platform/
├── .github/workflows/     # CI/CD pipelines
├── services/              # Microservices
│   ├── kyc-kyb-service/
│   ├── connector-service/
│   └── orchestration-service/
├── infrastructure/        # Terraform configurations
├── frontend/              # Lovable frontend
├── shared/                # Shared libraries
└── docs/                  # Documentation
```

## Getting Started

See individual service READMEs for setup instructions.

## Services

- **KYC/KYB Service**: Identity and company verification
- **Connector Service**: Vendor integration abstraction layer
- **Orchestration Service**: API gateway and request routing

## License

Proprietary

