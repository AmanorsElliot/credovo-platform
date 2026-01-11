# Credovo Architecture

## Overview

Credovo is built as a microservices architecture on Google Cloud Platform, designed for scalability, reliability, and global expansion.

## Components

### API Gateway
- **Orchestration Service**: Routes requests to appropriate microservices, handles authentication

### Microservices (Cloud Run)
- **Orchestration Service**: API gateway, authentication, request routing
- **KYC/KYB Service**: Identity and company verification (Shufti Pro, SumSub)
- **Company Search Service**: Company search and autocomplete (The Companies API)
- **Open Banking Service**: Financial data and income verification (Plaid)
- **Connector Service**: Vendor integration abstraction layer with circuit breakers and rate limiting

### Future Services (Planned)
- **AML & Fraud Service**: Anti-money laundering and fraud detection
- **Credit & Income Service**: Credit checks and income verification
- **Affordability Service**: Affordability calculations
- **Property AVM Service**: Automated property valuation
- **Payments Service**: Payment processing
- **Legal/Execution Service**: Legal document handling

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

1. Client application submits request to Orchestration Service
2. Orchestration Service authenticates request (JWT validation)
3. Orchestration Service routes to appropriate microservice
4. Microservice → Connector Service → External APIs
5. Results stored in Data Lake (GCS)
6. Events published to Pub/Sub for async processing
7. Status updates returned to client

## Security

- JWT-based authentication for user requests
- Service-to-service authentication using GCP service accounts
- Secrets stored in Secret Manager
- VPC connector for private resource access
- CORS configured for client applications

## Deployment

- Infrastructure as Code: Terraform
- CI/CD: Cloud Build (automatic builds on push)
- Container Registry: Artifact Registry
- Runtime: Cloud Run (serverless containers)

