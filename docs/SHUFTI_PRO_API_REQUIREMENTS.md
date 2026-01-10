# Shufti Pro API Requirements

Based on the [Shufti Pro Developer Tools](https://backoffice.shuftipro.com/integration/developer-tools) and our KYC/KYB verification needs, here are the APIs we'll need to implement.

## Required APIs

### 1. **Identity Verification API** (`/verify`)
**Purpose**: KYC (Know Your Customer) verification for individuals

**Endpoint**: `POST https://api.shuftipro.com/verify`

**What it does**:
- Verifies identity documents (passport, driver's license, national ID)
- Performs document authenticity checks
- Validates personal information (name, DOB, address)
- Can include face verification (liveness detection)
- Can include address verification

**Current Implementation**: ✅ Implemented in `shufti-pro-connector.ts`

**Request Structure**:
```json
{
  "reference": "unique-reference-id",
  "callback_url": "https://your-callback-url.com/webhook",
  "email": "user@example.com",
  "country": "GB",
  "language": "EN",
  "verification_mode": "any",
  "document": {
    "proof": "base64-encoded-document-image",
    "supported_types": ["passport", "driving_license", "id_card"],
    "name": {
      "first_name": "John",
      "last_name": "Doe",
      "middle_name": ""
    },
    "dob": "1990-01-01",
    "address": {
      "line1": "123 Main St",
      "city": "London",
      "postcode": "SW1A 1AA",
      "country": "GB"
    }
  },
  "face": {
    "proof": "base64-encoded-face-image"
  }
}
```

**Response**: Returns verification status (pending, accepted, declined)

---

### 2. **Business Verification API** (`/business`)
**Purpose**: KYB (Know Your Business) verification for companies

**Endpoint**: `POST https://api.shuftipro.com/business`

**What it does**:
- Verifies company registration information
- Checks company status and validity
- Validates company documents
- Verifies beneficial owners and directors
- Performs AML screening for businesses

**Current Implementation**: ✅ Implemented in `shufti-pro-connector.ts`

**Request Structure**:
```json
{
  "reference": "unique-reference-id",
  "callback_url": "https://your-callback-url.com/webhook",
  "email": "company@example.com",
  "country": "GB",
  "language": "EN",
  "business": {
    "name": "Acme Corporation Ltd",
    "registration_number": "12345678",
    "jurisdiction_code": "GB",
    "type": "limited_company",
    "address": {
      "line1": "123 Business St",
      "city": "London",
      "postcode": "SW1A 1AA",
      "country": "GB"
    }
  }
}
```

**Response**: Returns company verification status and details

---

### 3. **Status Check API** (`/status`)
**Purpose**: Check verification status by reference ID

**Endpoint**: `GET https://api.shuftipro.com/status/{reference}`

**What it does**:
- Retrieves current verification status
- Returns verification results
- Useful for polling when webhooks aren't available

**Current Implementation**: ⚠️ Partially implemented (used in `getKYCStatus`)

**Needs**: Full implementation with proper error handling

---

### 4. **Webhook/Callback API** (Our endpoint)
**Purpose**: Receive verification results asynchronously

**Endpoint**: `POST https://your-domain.com/api/v1/webhooks/shufti-pro`

**What it does**:
- Receives verification results from Shufti Pro
- Updates verification status in our system
- Publishes events to Pub/Sub for async processing
- Updates Data Lake with final results

**Current Implementation**: ❌ Not implemented yet

**Needs**: 
- Webhook endpoint in orchestration or KYC/KYB service
- Signature verification for security
- Event publishing to Pub/Sub

---

## Optional APIs (Future Enhancements)

### 5. **AML Screening API**
**Purpose**: Anti-Money Laundering checks

**When needed**:
- Enhanced compliance requirements
- High-risk customer screening
- Regulatory requirements

**Current Implementation**: ❌ Not implemented

**Note**: May be included in standard verification response

---

### 6. **Face Verification API**
**Purpose**: Biometric verification (liveness detection)

**Current Implementation**: ✅ Included in `/verify` endpoint (face.proof field)

**Status**: Already supported in our KYC flow

---

### 7. **Address Verification API**
**Purpose**: Verify user's address with official documents

**Current Implementation**: ✅ Included in `/verify` endpoint (document.address field)

**Status**: Already supported in our KYC flow

---

## Authentication

All APIs use **Basic Authentication**:
- **Username**: Client ID (`2OhMXk1rS9eqbsLSdHom5tUpWSAISVAT0RJC3TByNpsxhcakYn1768066741`)
- **Password**: Secret Key (`lm0PbtEjvHsLsD2doeoMsXlgDxRLBDAB`)
- **Header**: `Authorization: Basic base64(client_id:secret_key)`

**Current Implementation**: ✅ Implemented correctly

---

## Implementation Status

| API | Status | Priority | Notes |
|-----|--------|----------|-------|
| Identity Verification (`/verify`) | ✅ Implemented | High | Core KYC functionality |
| Business Verification (`/business`) | ✅ Implemented | High | Core KYB functionality |
| Status Check (`/status`) | ⚠️ Partial | Medium | Used for status polling |
| Webhook/Callback | ✅ Implemented | High | Receives async verification results |
| AML Screening | ✅ Implemented | High | Automatically included in all verifications |
| Face Verification | ✅ Included | Medium | Part of `/verify` |
| Address Verification | ✅ Included | Medium | Part of `/verify` |

---

## Next Steps

1. ✅ **Webhook Endpoint** - COMPLETED
   - Webhook handler created in orchestration service
   - Webhook processors created in KYC/KYB service
   - Automatic callback URL generation
   - Events published to Pub/Sub
   - **Action Required**: Register webhook URL in Shufti Pro back office

2. ✅ **AML Screening** - COMPLETED
   - Automatically included in all KYC/KYB verifications
   - Risk assessment with watchlist checks
   - Results stored in verification responses
   - Support for ongoing monitoring

3. **Enhance Status Check API** (Medium Priority)
   - Complete implementation in connector
   - Add proper error handling
   - Add retry logic for status checks

4. **Test Integration**
   - Test KYC verification flow with AML
   - Test KYB verification flow with AML
   - Test webhook callbacks
   - Verify data lake storage
   - Verify response mapping

---

## References

- [Shufti Pro Developer Tools](https://backoffice.shuftipro.com/integration/developer-tools)
- Current implementation: `services/connector-service/src/adapters/shufti-pro-connector.ts`
- KYC Service: `services/kyc-kyb-service/src/services/kyc-service.ts`
- KYB Service: `services/kyc-kyb-service/src/services/kyb-service.ts`

