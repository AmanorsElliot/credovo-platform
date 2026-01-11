# Clearbit API Setup via HubSpot

## Overview

Since Clearbit was acquired by HubSpot, accessing Clearbit's API requires a HubSpot account. This guide explains how to get your Clearbit API key for programmatic access.

## Step 1: Access Clearbit Dashboard

**Important**: Clearbit is not available as a standalone integration in the HubSpot marketplace. You need to access Clearbit directly.

### Getting Clearbit API Access

**Note**: Direct Clearbit login is no longer available. To get API access:

1. **Contact HubSpot/Clearbit Support**: 
   - Reach out to HubSpot support to request Clearbit API access
   - You may need a paid HubSpot plan that includes Clearbit
   - API access is not available through the HubSpot marketplace

2. **Alternative Options**:
   - Use **Companies House API** (already integrated, UK companies only)
   - Use **The Companies API** (UK-focused, standalone)
   - Consider other company data providers

## Step 2: Get Your API Key

**Note**: Clearbit API access requires contacting HubSpot/Clearbit support as direct login is no longer available.

### Getting Clearbit API Key:
1. In Clearbit dashboard, go to **Settings** → **API Keys**
2. If you don't have an API key:
   - Click **Create API Key** or **Generate New Key**
   - Give it a name (e.g., "Credovo Platform")
   - Copy the API key immediately (you won't be able to see it again)
3. If you already have keys, copy the one you want to use

**Important**: The API key format is typically a long alphanumeric string (e.g., `sk_live_xxxxxxxxxxxxx`)

**Note**: If Clearbit API access is not available, consider using **Companies House API** (already integrated for UK companies) or other company data providers.

## Step 3: Verify API Access

Test your API key works:

```bash
# Test company search
curl -X GET "https://company.clearbit.com/v2/companies/search?query=acme" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Accept: application/json"

# Test domain lookup
curl -X GET "https://company.clearbit.com/v2/companies/find?domain=acme.com" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Accept: application/json"
```

## Step 4: Store API Key in GCP Secret Manager

Once you have your Clearbit API key, store it securely:

```powershell
# Store Clearbit API key in Secret Manager
$apiKey = Read-Host "Enter your Clearbit API key" -AsSecureString
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($apiKey)
$plainApiKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

echo $plainApiKey | gcloud secrets create clearbit-api-key `
  --data-file=- `
  --project=credovo-eu-apps-nonprod `
  --replication-policy="user-managed" `
  --locations="europe-west1"
```

Or if the secret already exists, add a new version:

```powershell
echo $plainApiKey | gcloud secrets versions add clearbit-api-key `
  --data-file=- `
  --project=credovo-eu-apps-nonprod
```

## Step 5: Configure Terraform (Optional)

If you want to manage the secret via Terraform, add to `infrastructure/terraform/networking.tf`:

```hcl
resource "google_secret_manager_secret" "clearbit_api_key" {
  secret_id = "clearbit-api-key"
  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
}

# Note: Secret value should be added manually via gcloud or console
# Terraform doesn't manage secret values for security reasons
```

## Step 6: Update Cloud Run Environment Variables

The connector service needs access to the Clearbit API key. Update the connector service environment:

```bash
# Add Clearbit API key reference to connector service
gcloud run services update connector-service \
  --update-secrets=CLEARBIT_API_KEY=clearbit-api-key:latest \
  --region=europe-west1 \
  --project=credovo-eu-apps-nonprod
```

Or via Terraform in `infrastructure/terraform/cloud-run.tf`:

```hcl
resource "google_cloud_run_service" "connector_service" {
  # ... existing configuration ...
  
  template {
    spec {
      containers {
        env {
          name  = "CLEARBIT_API_KEY"
          value_from {
            secret_key_ref {
              name = "clearbit-api-key"
              key  = "latest"
            }
          }
        }
      }
    }
  }
}
```

## Step 7: Configure Company Search Service

Set the provider to use Clearbit:

```bash
# Update company-search-service to use Clearbit
gcloud run services update company-search-service \
  --update-env-vars=COMPANY_SEARCH_PROVIDER=clearbit \
  --region=europe-west1 \
  --project=credovo-eu-apps-nonprod
```

## Step 8: Test the Integration

Test the company search endpoint:

```bash
# Get authentication token
$token = .\scripts\get-test-token.ps1

# Test company search
curl -X GET "https://orchestration-service-xxx.run.app/api/v1/companies/search?query=acme&limit=10" \
  -H "Authorization: Bearer $token" \
  -H "Content-Type: application/json"
```

## Troubleshooting

### "API key not configured" error
- Verify the secret exists: `gcloud secrets describe clearbit-api-key`
- Check the secret value: `gcloud secrets versions access latest --secret=clearbit-api-key`
- Verify environment variable is set in Cloud Run service

### "Unauthorized" or "Invalid API key" error
- Verify your API key is correct and active
- Check if your HubSpot/Clearbit account has API access enabled
- Some HubSpot plans may not include Clearbit API access - check your plan

### "Rate limit exceeded" error
- Clearbit has rate limits based on your plan
- Check your usage in the Clearbit dashboard
- Consider implementing caching (already implemented in the service)

## API Rate Limits

Clearbit rate limits vary by plan:
- **Free tier**: Limited requests (if available)
- **Paid plans**: Higher limits (check your HubSpot/Clearbit plan)

## Resources

- [Clearbit API Documentation](https://clearbit.com/docs)
- [Clearbit Dashboard](https://dashboard.clearbit.com/)
- [HubSpot Clearbit Integration](https://help.clearbit.com/hc/en-us/articles/21570749175703-Clearbit-By-HubSpot-Set-Up-Clearbit-Enrichment-for-HubSpot)
- [Clearbit Support](https://support.clearbit.com/)

## Alternative: Using Companies House (UK Only)

If Clearbit is not available, you can use the Companies House API which is already integrated:

- **Companies House API**: UK company data (already integrated in connector service)
- No additional setup required
- Free tier available
- UK companies only
