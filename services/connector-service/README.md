# Connector Service

Abstraction layer for vendor integrations with support for:
- A/B testing and hot-swapping providers
- Rate limiting
- Circuit breaker pattern
- Retry logic with exponential backoff

## Supported Providers

- **SumSub**: KYC/KYB verification
- **Companies House**: UK company verification

## API Endpoints

### POST /api/v1/connector/call
Make a connector request to an external provider.

Request body:
```json
{
  "provider": "sumsub",
  "endpoint": "/resources/applicants",
  "method": "POST",
  "headers": {},
  "body": {},
  "retry": true
}
```

### GET /api/v1/connector/providers
List available providers and their features.

## Development

```bash
npm install
npm run dev
```

## Building

```bash
npm run build
```

## Testing

```bash
npm test
```

