# Service Interactions Walkthrough

This document explains how the three core services (`orchestration-service`, `kyc-kyb-service`, and `connector-service`) interact with each other in the Credovo platform.

## Architecture Overview

```
┌─────────────────┐
│  Frontend       │
│  (Lovable)      │
└────────┬────────┘
         │ HTTPS + JWT
         ▼
┌─────────────────────────┐
│  Orchestration Service  │  ← Entry point, routes requests
│  (API Gateway)          │
└─────┬───────────┬───────┘
      │           │
      │ HTTP      │ HTTP
      ▼           ▼
┌─────────────┐  ┌──────────────┐
│ KYC/KYB     │  │ Connector    │
│ Service     │──▶│ Service      │
└─────────────┘  └──────┬───────┘
                        │
                        │ HTTP
                        ▼
                  ┌─────────────┐
                  │ External    │
                  │ APIs        │
                  │ (SumSub,    │
                  │  Companies  │
                  │  House)     │
                  └─────────────┘
```

## Service Roles

### 1. Orchestration Service (API Gateway)
**Role**: Entry point and request router
- **Purpose**: Acts as the API gateway for the frontend
- **Responsibilities**:
  - Authenticates incoming requests (Supabase JWT or backend JWT)
  - Routes requests to appropriate microservices
  - Aggregates responses
  - Handles CORS for frontend

**Key Endpoints**:
- `POST /api/v1/applications/:applicationId/kyc/initiate` - Initiates KYC process
- `GET /api/v1/applications/:applicationId/kyc/status` - Gets KYC status

### 2. KYC/KYB Service (Business Logic)
**Role**: Handles identity and company verification
- **Purpose**: Manages KYC (Know Your Customer) and KYB (Know Your Business) processes
- **Responsibilities**:
  - Processes verification requests
  - Stores data in Data Lake (GCS)
  - Publishes events to Pub/Sub for async processing
  - Calls Connector Service to interact with external providers

**Key Endpoints**:
- `POST /api/v1/kyc/initiate` - Start KYC verification
- `GET /api/v1/kyc/status/:applicationId` - Get KYC status
- `POST /api/v1/kyb/verify` - Verify company information

### 3. Connector Service (Integration Layer)
**Role**: Abstraction layer for external vendor APIs
- **Purpose**: Provides a unified interface to external providers
- **Responsibilities**:
  - Manages connections to external APIs (SumSub, Companies House)
  - Implements circuit breaker pattern (prevents cascading failures)
  - Rate limiting (prevents API quota exhaustion)
  - Retry logic with exponential backoff
  - A/B testing and hot-swapping providers

**Key Endpoints**:
- `POST /api/v1/connector/call` - Make a request to an external provider
- `GET /api/v1/connector/providers` - List available providers

## Interaction Flow: KYC Verification Example

Here's a step-by-step walkthrough of what happens when a user initiates KYC verification:

### Step 1: Frontend Request
```
Frontend → POST /api/v1/applications/{appId}/kyc/initiate
Headers: Authorization: Bearer <Supabase JWT>
Body: { firstName, lastName, dateOfBirth, address }
```

### Step 2: Orchestration Service
**File**: `services/orchestration-service/src/routes/application.ts`

1. **Validates JWT** using `validateSupabaseJwt` middleware
2. **Extracts user ID** from JWT token (`req.userId`)
3. **Forwards request** to KYC/KYB Service:
   ```typescript
   POST http://kyc-kyb-service:8080/api/v1/kyc/initiate
   Headers: Authorization: Bearer <SERVICE_JWT_SECRET>
   Body: {
     applicationId,
     userId,
     firstName, lastName, dateOfBirth, address
   }
   ```

### Step 3: KYC/KYB Service Processing
**File**: `services/kyc-kyb-service/src/services/kyc-service.ts`

1. **Stores request in Data Lake** (GCS):
   ```typescript
   await this.dataLake.storeKYCRequest(request);
   ```

2. **Calls Connector Service** to interact with SumSub:
   ```typescript
   const connectorRequest = {
     provider: 'sumsub',
     endpoint: '/resources/applicants',
     method: 'POST',
     body: {
       externalUserId: request.userId,
       info: { firstName, lastName, dateOfBirth, address }
     },
     retry: true
   };
   
   const connectorResponse = await this.connector.call(connectorRequest);
   ```
   
   **File**: `services/kyc-kyb-service/src/services/connector-client.ts`
   - Makes HTTP POST to: `http://connector-service:8080/api/v1/connector/call`
   - Uses service-to-service authentication: `Bearer ${SERVICE_JWT_SECRET}`

3. **Stores response in Data Lake**:
   ```typescript
   await this.dataLake.storeKYCResponse(response);
   ```

4. **Publishes event to Pub/Sub** (async notification):
   ```typescript
   await this.pubsub.publishKYCEvent({
     applicationId: request.applicationId,
     event: 'kyc_initiated',
     status: 'pending',
     timestamp: new Date()
   });
   ```

5. **Returns response** to Orchestration Service (HTTP 202 Accepted)

### Step 4: Connector Service Processing
**File**: `services/connector-service/src/services/connector-manager.ts`

1. **Validates request** (provider, endpoint, method)

2. **Checks rate limit**:
   ```typescript
   if (!rateLimiter.allow()) {
     return { success: false, error: 'RATE_LIMIT_EXCEEDED' };
   }
   ```

3. **Checks circuit breaker**:
   ```typescript
   if (!circuitBreaker.allow()) {
     return { success: false, error: 'CIRCUIT_BREAKER_OPEN' };
   }
   ```

4. **Calls external API** (SumSub):
   ```typescript
   const result = await connector.call(request);
   // connector is SumSubConnector instance
   ```

5. **Records metrics** (latency, success/failure)

6. **Returns response**:
   ```typescript
   {
     success: true,
     data: { /* SumSub response */ }
   }
   ```

### Step 5: Response Flow Back
```
Connector Service → KYC/KYB Service → Orchestration Service → Frontend
```

## Communication Patterns

### 1. Synchronous HTTP Calls
- **Orchestration → KYC/KYB**: Direct HTTP calls using service URLs
- **KYC/KYB → Connector**: Direct HTTP calls using service URLs
- **Authentication**: Service-to-service uses `SERVICE_JWT_SECRET`

### 2. Asynchronous Events (Pub/Sub)
- **KYC/KYB Service** publishes events to `kyc-events` topic
- Other services can subscribe to these events for:
  - Status updates
  - Audit logging
  - Triggering downstream processes

### 3. Data Storage
- **Data Lake (GCS)**: All KYC/KYB requests and responses stored
- **BigQuery**: Analytics and reporting (future)

## Service URLs and Configuration

### Environment Variables

**Orchestration Service**:
- `KYC_SERVICE_URL`: `http://kyc-kyb-service:8080` (default)
- `SERVICE_JWT_SECRET`: For service-to-service auth

**KYC/KYB Service**:
- `CONNECTOR_SERVICE_URL`: `http://connector-service:8080` (default)
- `SERVICE_JWT_SECRET`: For service-to-service auth
- `PUBSUB_TOPIC`: `kyc-events` (default)

**Connector Service**:
- Provider-specific API keys stored in Secret Manager
- Rate limits and circuit breaker configs

## Authentication Flow

### User Requests (Frontend → Orchestration)
1. Frontend sends Supabase JWT in `Authorization` header
2. Orchestration Service validates JWT using JWKS or JWT secret
3. Extracts `userId` from JWT claims

### Service-to-Service Requests
1. Services use `SERVICE_JWT_SECRET` for authentication
2. Sent in `Authorization: Bearer <SERVICE_JWT_SECRET>` header
3. Services validate this secret before processing requests

## Error Handling

### Circuit Breaker Pattern (Connector Service)
- **Purpose**: Prevents cascading failures when external APIs are down
- **Behavior**:
  - After 5 failures, circuit opens
  - Requests fail fast for 1 minute
  - After timeout, allows one test request
  - If successful, circuit closes

### Rate Limiting (Connector Service)
- **Purpose**: Prevents API quota exhaustion
- **Config**: 100 requests per minute per provider
- **Behavior**: Returns `RATE_LIMIT_EXCEEDED` error when limit reached

### Retry Logic
- **Connector Service**: Automatic retry with exponential backoff
- **KYC/KYB Service**: Can request retry via `retry: true` flag

## Data Flow Summary

```
User Request
    ↓
Orchestration Service (validates JWT, routes request)
    ↓
KYC/KYB Service (business logic, stores in Data Lake)
    ↓
Connector Service (calls external API with resilience patterns)
    ↓
External API (SumSub, Companies House, etc.)
    ↓
Response flows back through the chain
    ↓
Pub/Sub event published (async notification)
    ↓
Frontend receives response
```

## Key Design Patterns

1. **API Gateway Pattern**: Orchestration Service acts as single entry point
2. **Service Mesh**: Services communicate via HTTP with service accounts
3. **Circuit Breaker**: Prevents cascading failures
4. **Rate Limiting**: Protects external API quotas
5. **Event-Driven**: Pub/Sub for async notifications
6. **Data Lake**: All requests/responses stored for audit and analytics

## Example: Complete KYC Flow

```typescript
// 1. Frontend calls Orchestration
POST /api/v1/applications/123/kyc/initiate
{
  "firstName": "John",
  "lastName": "Doe",
  "dateOfBirth": "1990-01-01",
  "address": "123 Main St"
}

// 2. Orchestration forwards to KYC Service
POST http://kyc-kyb-service:8080/api/v1/kyc/initiate
{
  "applicationId": "123",
  "userId": "user-456",
  "firstName": "John",
  "lastName": "Doe",
  "dateOfBirth": "1990-01-01",
  "address": "123 Main St"
}

// 3. KYC Service calls Connector
POST http://connector-service:8080/api/v1/connector/call
{
  "provider": "sumsub",
  "endpoint": "/resources/applicants",
  "method": "POST",
  "body": {
    "externalUserId": "user-456",
    "info": {
      "firstName": "John",
      "lastName": "Doe",
      "dateOfBirth": "1990-01-01",
      "address": "123 Main St"
    }
  },
  "retry": true
}

// 4. Connector calls SumSub API
POST https://api.sumsub.com/resources/applicants
[SumSub API call with authentication]

// 5. Response flows back
SumSub → Connector → KYC Service → Orchestration → Frontend

// 6. Async event published
Pub/Sub Topic: kyc-events
{
  "applicationId": "123",
  "event": "kyc_initiated",
  "status": "pending",
  "timestamp": "2026-01-10T12:00:00Z"
}
```

## Service Dependencies

```
orchestration-service
  └─ depends on: kyc-kyb-service

kyc-kyb-service
  ├─ depends on: connector-service
  ├─ depends on: Data Lake (GCS)
  └─ publishes to: Pub/Sub

connector-service
  └─ depends on: External APIs (SumSub, Companies House)
```

## Monitoring and Observability

- **Logging**: All services use structured logging via `@credovo/shared-utils/logger`
- **Metrics**: Connector Service tracks latency and success rates
- **Health Checks**: All services expose `/health` endpoints
- **Cloud Monitoring**: GCP native monitoring for Cloud Run services

