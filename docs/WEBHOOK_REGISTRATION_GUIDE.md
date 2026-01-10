# Shufti Pro Webhook Registration Guide

## What to Register

**Type**: **Callback URL** (Webhook) - NOT a redirect URL

**URL**: `https://orchestration-service-saz24fo3sa-ew.a.run.app/api/v1/webhooks/shufti-pro`

## Step-by-Step Instructions

### 1. Log in to Shufti Pro Back Office
- Go to: https://backoffice.shuftipro.com
- Log in with your credentials

### 2. Navigate to Settings
- Look for **Settings** in the main menu
- Or go to **Integration** → **Settings**
- Or **Developer Tools** → **Settings**

### 3. Find Webhook/Callback Configuration
- Look for **"Webhook URL"** or **"Callback URL"** field
- This is different from "Redirect URL" (which is for user redirects)

### 4. Enter Your Webhook URL
```
https://orchestration-service-saz24fo3sa-ew.a.run.app/api/v1/webhooks/shufti-pro
```

### 5. Save Configuration
- Click **Save** or **Update**
- Shufti Pro may test the endpoint (expect a test POST request)

## What Happens Next

1. **Shufti Pro will send POST requests** to your endpoint when:
   - Verification is completed
   - Verification status changes
   - AML screening results are ready

2. **Your endpoint will receive**:
   - Verification results
   - Status updates
   - Reference IDs
   - Extracted data
   - AML screening results

3. **Your endpoint must**:
   - Return `200 OK` to acknowledge receipt
   - Process the webhook data
   - Store results in data lake
   - Publish events to Pub/Sub

## Verification

After registering, you can verify it's working by:

1. **Check Shufti Pro Back Office**:
   - Some interfaces show webhook status/test results
   - Look for "Webhook Status" or "Test Webhook" option

2. **Initiate a test verification**:
   - Start a KYC or KYB verification
   - Check your Cloud Run logs for webhook receipt
   - Check data lake for stored webhook data

3. **Check logs**:
   ```bash
   gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=orchestration-service AND textPayload=~'webhook'" --limit=10 --project=credovo-eu-apps-nonprod
   ```

## Important Notes

- ✅ **Callback URL** = Server-to-server webhook (what you need)
- ❌ **Redirect URL** = User browser redirect (not needed for this)
- The endpoint accepts POST requests with JSON payloads
- No authentication required (Shufti Pro sends from their servers)
- Webhook will be called asynchronously after verification completes

## Troubleshooting

**If webhook isn't being called:**
1. Verify URL is correct (no typos)
2. Check if Cloud Run service is publicly accessible
3. Verify endpoint accepts POST requests
4. Check Cloud Run logs for incoming requests
5. Contact Shufti Pro support if needed

**If webhook returns errors:**
1. Check Cloud Run logs for error details
2. Ensure endpoint returns 200 OK
3. Verify JSON parsing is working
4. Check data lake storage permissions

## Security Considerations

- **IP Whitelisting** (Recommended):
  - Shufti Pro sends from specific IP addresses
  - Contact Shufti Pro support for their IP ranges
  - Configure Cloud Run/load balancer to accept only from these IPs

- **Signature Verification** (Future):
  - Currently placeholder in code
  - Will implement when Shufti Pro documentation is available
  - File: `services/orchestration-service/src/routes/webhooks.ts`

## References

- [Shufti Pro Webhook Documentation](https://support.shuftipro.com/hc/en-us/articles/9511003514269-How-can-I-get-webhook-responses)
- Webhook handler: `services/orchestration-service/src/routes/webhooks.ts`
- KYC/KYB webhook processor: `services/kyc-kyb-service/src/routes/webhooks.ts`

