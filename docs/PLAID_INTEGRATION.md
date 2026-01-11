# Plaid Open Banking Integration

## Overview

The Credovo platform now includes Plaid integration for open banking functionality, enabling:
- **Account Verification**: Verify bank account ownership and details
- **Transaction History**: Access categorized transaction data
- **Income Verification**: Automated income verification from bank statements
- **Identity Verification**: Confirm user identities via bank account information

## Architecture

### Components

1. **Plaid Connector** (`services/connector-service/src/adapters/plaid-connector.ts`)
   - Handles all Plaid API interactions
   - Supports sandbox and production environments
   - Implements error handling and retry logic

2. **Open Banking Service** (`services/open-banking-service/`)
   - Dedicated microservice for banking operations
   - Handles link token creation, token exchange, account queries
   - Manages income verification workflows

3. **Orchestration Service Routes** (`services/orchestration-service/src/routes/banking.ts`)
   - API gateway endpoints for banking operations
   - User-facing REST API

4. **Webhook Handler** (`services/orchestration-service/src/routes/webhooks.ts`)
   - Processes Plaid webhooks for real-time updates
   - Handles transaction updates, income verification status, item errors

## API Endpoints

### Create Link Token
**POST** `/api/v1/applications/:applicationId/banking/link-token`

Creates a Plaid Link token for frontend integration.

**Request:**
```json
{
  "products": ["transactions", "auth"],
  "redirectUri": "https://yourapp.com/callback",
  "institutionId": "ins_123" // Optional: pre-select institution
}
```

**Response:**
```json
{
  "linkToken": "link-sandbox-xxx",
  "expiration": "2024-01-01T00:00:00Z",
  "requestId": "req_xxx"
}
```

### Exchange Public Token
**POST** `/api/v1/applications/:applicationId/banking/exchange-token`

Exchanges a public token (from Plaid Link) for an access token.

**Request:**
```json
{
  "publicToken": "public-sandbox-xxx"
}
```

**Response:**
```json
{
  "accessToken": "access-sandbox-xxx",
  "itemId": "item_xxx",
  "requestId": "req_xxx"
}
```

### Get Account Balances
**POST** `/api/v1/applications/:applicationId/banking/accounts/balance`

Retrieves account balances for linked accounts.

**Request:**
```json
{
  "accessToken": "access-sandbox-xxx",
  "accountIds": ["acc_123"] // Optional: specific accounts
}
```

**Response:**
```json
{
  "accounts": [
    {
      "accountId": "acc_123",
      "accountName": "Plaid Checking",
      "accountType": "checking",
      "institutionName": "Chase",
      "balance": {
        "available": 1000.00,
        "current": 1000.00,
        "currency": "USD"
      }
    }
  ],
  "requestId": "req_xxx"
}
```

### Get Transactions
**POST** `/api/v1/applications/:applicationId/banking/transactions`

Retrieves transaction history.

**Request:**
```json
{
  "accessToken": "access-sandbox-xxx",
  "accountId": "acc_123", // Optional
  "startDate": "2024-01-01",
  "endDate": "2024-01-31",
  "count": 100
}
```

**Response:**
```json
{
  "transactions": [
    {
      "transactionId": "txn_123",
      "accountId": "acc_123",
      "amount": -50.00,
      "currency": "USD",
      "date": "2024-01-15",
      "name": "Starbucks",
      "category": ["Food and Drink", "Restaurants"],
      "type": "debit",
      "pending": false
    }
  ],
  "totalTransactions": 50,
  "requestId": "req_xxx"
}
```

### Create Income Verification
**POST** `/api/v1/applications/:applicationId/banking/income/verify`

Initiates automated income verification.

**Request:**
```json
{
  "accessToken": "access-sandbox-xxx"
}
```

**Response:**
```json
{
  "applicationId": "app_123",
  "userId": "user_123",
  "status": "pending",
  "provider": "plaid",
  "timestamp": "2024-01-01T00:00:00Z"
}
```

## Frontend Integration

### 1. Initialize Plaid Link

```javascript
import { usePlaidLink } from 'react-plaid-link';

function BankingLink({ linkToken, onSuccess }) {
  const { open, ready } = usePlaidLink({
    token: linkToken,
    onSuccess: (publicToken, metadata) => {
      // Send publicToken to backend
      onSuccess(publicToken);
    },
  });

  return (
    <button onClick={() => open()} disabled={!ready}>
      Connect Bank Account
    </button>
  );
}
```

### 2. Exchange Token

```javascript
const response = await fetch(
  `/api/v1/applications/${applicationId}/banking/exchange-token`,
  {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${userToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ publicToken }),
  }
);

const { accessToken, itemId } = await response.json();
// Store accessToken securely for future API calls
```

## Configuration

### Environment Variables

**Required:**
- `PLAID_CLIENT_ID`: Plaid client ID
- `PLAID_SECRET_KEY`: Plaid secret key
- `PLAID_ENV`: Environment (`sandbox` or `production`)

**Optional:**
- `PLAID_WEBHOOK_VERIFICATION_KEY`: For webhook signature verification
- `OPEN_BANKING_SERVICE_URL`: Open banking service URL (auto-detected in Cloud Run)

### Production Access Limitations

**⚠️ Important**: Current Plaid production credentials have **Limited Production access**:
- ✅ Can access live data from institutions that **don't use OAuth**
- ❌ Cannot connect to institutions that **require OAuth**
- This limitation will be resolved when full production access is granted

**Impact:**
- Some banks may not be available for connection
- Users attempting to connect OAuth-only banks will see an error
- Consider showing a message to users: "Some banks may not be available. If your bank is not listed, please contact support."

**Future**: When full production access is granted, OAuth institutions will become available automatically.

### Secret Manager

Store Plaid credentials in GCP Secret Manager:

```bash
# Development/Sandbox
gcloud secrets create plaid-client-id --data-file=- <<< "your-client-id"
gcloud secrets create plaid-secret-key --data-file=- <<< "your-secret-key"

# Production
gcloud secrets create plaid-client-id-prod --data-file=- <<< "your-production-client-id"
gcloud secrets create plaid-secret-key-prod --data-file=- <<< "your-production-secret-key"
```

## Webhooks

Plaid sends webhooks for:
- **Transaction Updates**: New transactions, historical updates
- **Income Verification**: Verification completion
- **Item Errors**: Account connection issues

Webhook endpoint: `POST /api/v1/webhooks/plaid`

### Webhook Types

- `TRANSACTIONS`: Transaction updates
- `INCOME`: Income verification status
- `ITEM`: Item/account status changes

## Testing

### Sandbox Testing

Plaid provides sandbox credentials for testing:
- Use test credentials from Plaid Dashboard
- Test with sandbox institutions
- Simulate various scenarios (success, errors, etc.)

### Test Scripts

```powershell
# Test link token creation
.\scripts\test-plaid.ps1 -Action CreateLinkToken -ApplicationId "test-app-123"

# Test token exchange
.\scripts\test-plaid.ps1 -Action ExchangeToken -PublicToken "public-sandbox-xxx"

# Test account balance
.\scripts\test-plaid.ps1 -Action GetBalance -AccessToken "access-sandbox-xxx"
```

## Security

1. **Token Storage**: Store access tokens securely (encrypted, in Secret Manager)
2. **Webhook Verification**: Verify webhook signatures (HMAC-SHA256)
3. **HTTPS Only**: All API calls must use HTTPS
4. **Access Control**: Validate user ownership of linked accounts
5. **Data Encryption**: Encrypt sensitive banking data at rest

## Error Handling

Common Plaid errors:
- `INVALID_ACCESS_TOKEN`: Token expired or invalid
- `ITEM_LOGIN_REQUIRED`: User needs to reconnect account
- `RATE_LIMIT_EXCEEDED`: Too many requests
- `INSTITUTION_DOWN`: Bank temporarily unavailable

Handle errors gracefully and provide user-friendly messages.

## Production Checklist

- [ ] Set `PLAID_ENV=production`
- [ ] Configure production credentials in Secret Manager
- [ ] **Note**: Current production access is Limited (no OAuth institutions)
- [ ] Set up webhook endpoint in Plaid Dashboard
- [ ] Configure webhook verification key
- [ ] Test end-to-end flow in production (non-OAuth institutions only)
- [ ] Set up monitoring and alerts
- [ ] Document incident response procedures
- [ ] Review compliance requirements (GDPR, PCI-DSS)
- [ ] Update when full production access is granted (OAuth support)

## Resources

- [Plaid API Documentation](https://plaid.com/docs/)
- [Plaid Quickstart](https://github.com/plaid/quickstart)
- [Plaid Postman Collection](https://github.com/plaid/plaid-postman)
- [Plaid Support](https://support.plaid.com/)
