# Shufti Pro Webhook Setup

This document explains the webhook/callback endpoint setup for receiving verification results from Shufti Pro.

## Webhook Endpoint

**URL Format**: `https://{orchestration-service-url}/api/v1/webhooks/shufti-pro`

**Example**: `https://orchestration-service-saz24fo3sa-ew.a.run.app/api/v1/webhooks/shufti-pro`

## How It Works

1. **KYC/KYB Service** initiates verification with Shufti Pro
   - Includes `callback_url` in the request
   - Callback URL points to orchestration service webhook endpoint

2. **Shufti Pro** processes the verification
   - Performs document verification
   - Performs face verification (if enabled)
   - Performs AML screening (if enabled)
   - Verifies business information (for KYB)

3. **Shufti Pro** sends webhook to our endpoint
   - POST request with verification results
   - Includes reference ID, status, and extracted data
   - Includes AML screening results (if enabled)

4. **Orchestration Service** receives webhook
   - Routes to KYC/KYB service based on reference ID
   - No authentication required (webhooks come from Shufti Pro)

5. **KYC/KYB Service** processes webhook
   - Stores raw webhook data in data lake
   - Updates verification status
   - Publishes events to Pub/Sub
   - Returns 200 OK to acknowledge receipt

## Data Lake Storage

All verification data is stored in the data lake:

### Storage Structure

```
GCS Bucket: credovo-eu-apps-nonprod-data-lake-raw/
├── kyc/
│   ├── requests/          # Initial KYC requests
│   ├── responses/        # Processed KYC responses
│   ├── api-requests/     # Raw API requests sent to Shufti Pro
│   ├── api-responses/    # Raw API responses from Shufti Pro
│   └── webhooks/         # Raw webhook data from Shufti Pro
└── kyb/
    ├── requests/          # Initial KYB requests
    ├── responses/         # Processed KYB responses
    ├── api-requests/     # Raw API requests sent to Shufti Pro
    ├── api-responses/    # Raw API responses from Shufti Pro
    └── webhooks/         # Raw webhook data from Shufti Pro
```

### What Gets Stored

1. **Requests**: Initial KYC/KYB requests from frontend
2. **API Requests**: Raw requests sent to Shufti Pro (including credentials, documents, etc.)
3. **API Responses**: Initial responses from Shufti Pro API
4. **Webhooks**: Final verification results from Shufti Pro webhooks
5. **Responses**: Processed responses stored in our format

## AML Screening

AML (Anti-Money Laundering) screening is automatically included in all verifications:

### For KYC (Individuals)
- Checks against global watchlists
- Risk assessment scoring
- Flags for suspicious activity
- Results included in verification response

### For KYB (Companies)
- Business entity screening
- Director/beneficial owner checks
- Company watchlist screening
- Results included in verification response

### Ongoing Monitoring

To enable ongoing AML monitoring (continuous screening):
- Set `aml_ongoing: 1` in the verification request
- Shufti Pro will send webhook notifications if AML status changes
- Useful for detecting changes in customer risk profile over time

## Security

### Webhook Security

1. **IP Whitelisting** (Recommended)
   - Shufti Pro sends webhooks from specific IP addresses
   - Configure firewall/load balancer to only accept from these IPs
   - Contact Shufti Pro support for their IP ranges

2. **Signature Verification** (If available)
   - Shufti Pro may provide webhook signatures
   - Verify signatures to ensure authenticity
   - Implementation pending Shufti Pro documentation

3. **Always Return 200 OK**
   - Webhook endpoint must return 200 OK to acknowledge receipt
   - Shufti Pro will retry up to 10 times if not acknowledged
   - Errors should be logged but still return 200 OK

## Configuration

### Register Callback URL in Shufti Pro Back Office

1. Log in to [Shufti Pro Back Office](https://backoffice.shuftipro.com)
2. Go to **Settings** → **Integration**
3. Add your webhook URL: `https://{orchestration-service-url}/api/v1/webhooks/shufti-pro`
4. Save the configuration

### Environment Variables

The orchestration service URL is automatically configured via Terraform:
- `ORCHESTRATION_SERVICE_URL` - Set in KYC/KYB service environment

## Testing

### Test Webhook Endpoint

```bash
# Health check
curl https://orchestration-service-url/api/v1/webhooks/health

# Test webhook (simulate Shufti Pro callback)
curl -X POST https://orchestration-service-url/api/v1/webhooks/shufti-pro \
  -H "Content-Type: application/json" \
  -d '{
    "reference": "kyc-test-123-1234567890",
    "event": "verification.accepted",
    "verification_result": {
      "event": "verification.accepted",
      "document": {
        "verification_status": "approved"
      },
      "risk_assessment": {
        "verification_status": "approved",
        "risk_score": 10
      }
    }
  }'
```

## Monitoring

- Webhook requests are logged in Cloud Logging
- Failed webhooks are logged with full error details
- Data lake storage is logged for audit trail
- Pub/Sub events are published for async processing

## References

- [Shufti Pro Webhook Documentation](https://support.shuftipro.com/hc/en-us/articles/9511003514269-How-can-I-get-webhook-responses)
- [Shufti Pro AML Screening](https://support.shuftipro.com/hc/en-us/articles/6576417232797-What-is-On-going-AML-Service)
- Webhook handler: `services/orchestration-service/src/routes/webhooks.ts`
- KYC/KYB webhook processor: `services/kyc-kyb-service/src/routes/webhooks.ts`

