# KYC/KYB Service

Service for identity verification (KYC) and company verification (KYB).

## API Endpoints

### POST /api/v1/kyc/initiate
Initiate a KYC verification process.

### GET /api/v1/kyc/status/:applicationId
Get the status of a KYC verification.

### POST /api/v1/kyb/verify
Verify a company using Companies House.

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

