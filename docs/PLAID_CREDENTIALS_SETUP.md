# Plaid Credentials Setup

## ✅ Credentials Configured

Plaid credentials have been successfully configured in GCP Secret Manager:

### Secrets Created

1. **plaid-client-id**
   - Value: `695f4eebbd1561001d2a5159`
   - Location: `europe-west1`
   - Status: ✅ Active

2. **plaid-secret-key** (Sandbox)
   - Value: `2bf99d20b80c1cebf3b98da518f220`
   - Location: `europe-west1`
   - Status: ✅ Active
   - Environment: Non-production (sandbox)

3. **plaid-secret-key-prod** (Production)
   - Value: `4fa53299017068600116eb956c80de`
   - Location: `europe-west1`
   - Status: ✅ Active
   - Environment: Production (for future use)

## Configuration

### Terraform

The Plaid secrets are defined in `infrastructure/terraform/networking.tf`:

```hcl
resource "google_secret_manager_secret" "plaid_client_id" {
  secret_id = "plaid-client-id"
  # ... configuration
}

resource "google_secret_manager_secret" "plaid_secret_key" {
  secret_id = "plaid-secret-key"
  # ... configuration
}
```

### Cloud Run Services

The connector service is configured to use Plaid credentials via environment variables:

- `PLAID_CLIENT_ID` - From Secret Manager
- `PLAID_SECRET_KEY` - From Secret Manager (sandbox for nonprod)
- `PLAID_ENV` - Set to `sandbox` for nonprod, `production` for prod

### IAM Permissions

The connector service has been granted access to Plaid secrets:

```hcl
resource "google_secret_manager_secret_iam_member" "connector_plaid_client_id_access" {
  secret_id = google_secret_manager_secret.plaid_client_id.secret_id
  member    = "serviceAccount:${google_service_account.services["connector-service"].email}"
  role      = "roles/secretmanager.secretAccessor"
}
```

## Usage

### Current Environment (Non-Production)

- **Environment**: `sandbox`
- **Client ID**: `695f4eebbd1561001d2a5159`
- **Secret Key**: `2bf99d20b80c1cebf3b98da518f220`
- **Base URL**: `https://sandbox.plaid.com`

### Production (Current - Limited Access)

**⚠️ Important Limitation**: Current production credentials have **Limited Production access**:
- ✅ Can access live data from institutions that **don't use OAuth**
- ❌ Cannot connect to institutions that **require OAuth**
- This will change when full production access is granted

When deploying to production:
1. Update `PLAID_ENV` to `production` in Cloud Run
2. Update `PLAID_SECRET_KEY` to reference `plaid-secret-key-prod`
3. Base URL will automatically switch to `https://production.plaid.com`
4. **Note**: Only non-OAuth institutions will be available until full access is granted

## Testing

### Verify Secrets

```bash
# Check client ID
gcloud secrets versions access latest --secret=plaid-client-id --project=credovo-eu-apps-nonprod

# Check sandbox secret
gcloud secrets versions access latest --secret=plaid-secret-key --project=credovo-eu-apps-nonprod

# Check production secret
gcloud secrets versions access latest --secret=plaid-secret-key-prod --project=credovo-eu-apps-nonprod
```

### Test Plaid Integration

1. **Create Link Token**
   ```bash
   curl -X POST https://orchestration-service-xxx.run.app/api/v1/applications/test-app/banking/link-token \
     -H "Authorization: Bearer YOUR_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"products": ["transactions", "auth"]}'
   ```

2. **Use Plaid Sandbox**
   - Use test credentials: `user_good` / `pass_good`
   - Test institutions: `ins_109508`, `ins_109509`, etc.
   - See [Plaid Sandbox Guide](https://plaid.com/docs/sandbox/)

## Security Notes

- ✅ Secrets stored in GCP Secret Manager (encrypted at rest)
- ✅ Regional replication in `europe-west1`
- ✅ IAM-based access control
- ✅ Separate secrets for sandbox and production
- ✅ No credentials in code or version control

## Next Steps

1. **Deploy Services**: Run Terraform apply to update Cloud Run services
2. **Test Integration**: Use Plaid sandbox to test the integration
3. **Configure Webhooks**: Set up webhook endpoint in Plaid Dashboard
4. **Production Setup**: When ready, switch to production credentials
   - **Note**: Current production access is Limited (no OAuth institutions)
   - Full production access will enable OAuth institution support

## Resources

- [Plaid Dashboard](https://dashboard.plaid.com/)
- [Plaid API Documentation](https://plaid.com/docs/)
- [Plaid Sandbox Guide](https://plaid.com/docs/sandbox/)
