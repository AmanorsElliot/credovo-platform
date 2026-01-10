# Testing Guide - Credovo Platform

This guide explains how to test the Credovo platform end-to-end, including KYC/KYB verification flows, webhooks, and data lake storage.

## Quick Start

### Run Comprehensive Test Suite

```powershell
# Basic test run
.\scripts\test-comprehensive.ps1

# With authentication token
.\scripts\test-comprehensive.ps1 -AuthToken "your-supabase-jwt-token"

# Custom application ID
.\scripts\test-comprehensive.ps1 -ApplicationId "my-test-app-123"

# Skip webhook or data lake checks
.\scripts\test-comprehensive.ps1 -SkipWebhook -SkipDataLake

# Custom retry settings
.\scripts\test-comprehensive.ps1 -StatusCheckRetries 10 -StatusCheckDelay 3
```

### Run Basic Integration Test

The comprehensive test suite (`test-comprehensive.ps1`) includes all integration tests. For basic testing, use:

```powershell
.\scripts\test-comprehensive.ps1 -SkipWebhook -SkipDataLake
```

## Test Coverage

### Comprehensive Test Suite (`test-comprehensive.ps1`)

The comprehensive test suite includes:

1. **Health Checks**
   - Orchestration service health
   - Webhook endpoint health

2. **KYC Verification Flow**
   - KYC initiation
   - Status polling with retries
   - AML results verification

3. **KYB Verification Flow**
   - KYB initiation
   - Business verification

4. **Webhook Endpoint**
   - Health check
   - Endpoint availability

5. **Data Lake Storage**
   - KYC request storage verification
   - KYB request storage verification
   - GCS bucket access

6. **Error Handling**
   - Invalid application ID handling
   - 404 error responses
   - Error message validation

## Test Scenarios

### Scenario 1: Complete KYC Flow

```powershell
# 1. Initiate KYC
$kycRequest = @{
    type = "individual"
    data = @{
        firstName = "John"
        lastName = "Doe"
        dateOfBirth = "1990-01-01"
        email = "john.doe@example.com"
        country = "GB"
        address = @{
            line1 = "123 Test Street"
            city = "London"
            postcode = "SW1A 1AA"
            country = "GB"
        }
    }
}

$response = Invoke-RestMethod `
    -Uri "https://orchestration-service-saz24fo3sa-ew.a.run.app/api/v1/applications/test-app-123/kyc/initiate" `
    -Method Post `
    -Headers @{ "Content-Type" = "application/json"; "Authorization" = "Bearer YOUR_TOKEN" } `
    -Body ($kycRequest | ConvertTo-Json -Depth 10)

# 2. Check status (poll until complete)
$status = Invoke-RestMethod `
    -Uri "https://orchestration-service-saz24fo3sa-ew.a.run.app/api/v1/applications/test-app-123/kyc/status" `
    -Method Get `
    -Headers @{ "Authorization" = "Bearer YOUR_TOKEN" }
```

### Scenario 2: KYB Verification

```powershell
$kybRequest = @{
    companyNumber = "12345678"
    companyName = "Test Company Ltd"
    country = "GB"
    email = "company@example.com"
}

$response = Invoke-RestMethod `
    -Uri "https://orchestration-service-saz24fo3sa-ew.a.run.app/api/v1/applications/test-app-123/kyb/verify" `
    -Method Post `
    -Headers @{ "Content-Type" = "application/json"; "Authorization" = "Bearer YOUR_TOKEN" } `
    -Body ($kybRequest | ConvertTo-Json -Depth 10)
```

## Verifying Results

### Check Cloud Run Logs

```powershell
# Webhook callbacks
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=orchestration-service AND textPayload=~'webhook'" --limit=10 --project=credovo-eu-apps-nonprod

# KYC/KYB processing
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=kyc-kyb-service AND severity>=WARNING" --limit=20 --project=credovo-eu-apps-nonprod
```

### Check Data Lake Storage

```powershell
# List KYC requests
gsutil ls gs://credovo-eu-apps-nonprod-data-lake-raw/kyc/requests/

# List KYB requests
gsutil ls gs://credovo-eu-apps-nonprod-data-lake-raw/kyb/requests/

# Download a specific file
gsutil cp gs://credovo-eu-apps-nonprod-data-lake-raw/kyc/requests/test-app-123/1234567890.json .
```

### Check Monitoring Dashboards

1. Go to [GCP Console - Monitoring](https://console.cloud.google.com/monitoring)
2. Navigate to **Dashboards** → **Credovo Platform Dashboard**
3. Review:
   - Error rates
   - Latency metrics
   - Webhook activity
   - KYC/KYB success rates

## Status Check API

The status check API now includes:

- **Retry Logic**: Automatically retries failed status checks (up to 3 times)
- **Exponential Backoff**: Delays between retries (2s, 4s, 8s)
- **Error Handling**: Graceful handling of provider errors
- **Response Mapping**: Proper mapping of Shufti Pro responses

### Status Check Flow

1. First checks data lake for stored response
2. If not found, queries Shufti Pro status API
3. Retries on failure with exponential backoff
4. Stores result in data lake for future queries
5. Returns mapped response

## Webhook Security

Webhook endpoints now include:

- **Signature Verification**: HMAC-SHA256 signature validation
- **IP Whitelisting**: Optional IP-based access control
- **Security Logging**: All security events are logged
- **Graceful Handling**: Invalid signatures are logged but don't block (configurable)

### Webhook Signature Verification

The webhook handler verifies signatures if provided:

```typescript
// Signature is verified using HMAC-SHA256
// Secret key from SHUFTI_PRO_SECRET_KEY environment variable
// Signature header: x-shufti-signature or x-shufti-pro-signature
```

### IP Whitelisting

Configure allowed IPs via environment variable:

```bash
SHUFTI_PRO_ALLOWED_IPS=1.2.3.4,5.6.7.8/24
```

## Troubleshooting

### Test Failures

1. **Authentication Errors**
   - Ensure you have a valid Supabase JWT token
   - Check token expiration
   - Verify token has required permissions

2. **Status Check Timeouts**
   - Increase `-StatusCheckRetries` parameter
   - Increase `-StatusCheckDelay` parameter
   - Verification may still be processing (async)

3. **Data Lake Not Found**
   - Wait a few minutes (async writes)
   - Check GCS bucket permissions
   - Verify service account has storage access

4. **Webhook Not Received**
   - Check Shufti Pro back office for webhook status
   - Verify domain whitelist is configured
   - Check Cloud Run logs for webhook attempts

### Common Issues

**Issue**: Status check returns 404
- **Solution**: Status may not be available yet (async processing). Wait and retry.

**Issue**: Webhook signature verification fails
- **Solution**: Check if Shufti Pro is sending signatures. May need to verify exact signature method with Shufti Pro docs.

**Issue**: Data lake files not found
- **Solution**: Files are written asynchronously. Wait 1-2 minutes and check again.

## Next Steps

After running tests:

1. Review test results
2. Check Cloud Run logs for any errors
3. Verify data lake storage
4. Review monitoring dashboards
5. Test webhook callbacks manually (if needed)

## Manual Testing

For manual testing of specific scenarios:

1. Use Postman or curl
2. Follow API documentation in `docs/SERVICE_INTERACTIONS.md`
3. Check logs in real-time: `gcloud logging tail`
4. Monitor dashboards during testing

## Continuous Testing

Consider setting up:

- Automated test runs in CI/CD
- Scheduled health checks
- Alert policies for test failures
- Test result reporting

