# Credovo Architecture

## Overview

Credovo is built as a microservices architecture on Google Cloud Platform, designed for scalability, reliability, and global expansion.

## Components

### Frontend Layer
- **Lovable Frontend**: React-based frontend application
- **Lovable Cloud Auth**: Authentication and user management

### API Gateway
- **Orchestration Service**: Routes requests to appropriate microservices, handles authentication

### Microservices (Cloud Run)
- **KYC/KYB Service**: Identity and company verification
- **AML & Fraud Service**: Anti-money laundering and fraud detection
- **Credit & Income Service**: Credit checks and income verification
- **Affordability Service**: Affordability calculations
- **Property AVM Service**: Automated property valuation
- **Payments Service**: Payment processing
- **Legal/Execution Service**: Legal document handling
- **Connector Service**: Vendor integration abstraction layer

### Data Layer
- **GCS Data Lake**: Raw data storage with lifecycle policies
- **BigQuery**: Data warehouse for analytics
- **Cloud SQL**: PostgreSQL for transactional data

### Infrastructure
- **Secret Manager**: Secure storage of API keys and secrets
- **Cloud Tasks**: Asynchronous task processing
- **Pub/Sub**: Event-driven messaging
- **Cloud Monitoring**: Observability and alerting

## Data Flow

1. User submits application via Lovable frontend
2. Frontend authenticates with Lovable Cloud Auth
3. Authenticated request → Orchestration Service
4. Orchestration Service routes to appropriate microservice
5. Microservice → Connector Service → External APIs
6. Results stored in Data Lake (GCS)
7. Events published to Pub/Sub for async processing
8. Status updates returned to frontend

## Security

- JWT-based authentication for user requests
- Service-to-service authentication using GCP service accounts
- Secrets stored in Secret Manager
- VPC connector for private resource access
- CORS configured for Lovable frontend domain

## Deployment

- Infrastructure as Code: Terraform
- CI/CD: GitHub Actions + Cloud Build
- Container Registry: Artifact Registry
- Runtime: Cloud Run (serverless containers)

