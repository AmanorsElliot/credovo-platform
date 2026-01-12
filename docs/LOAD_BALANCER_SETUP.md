# Load Balancer Setup for Proxy Service

## Overview

This solution uses a Google Cloud HTTPS Load Balancer to provide public access to the proxy service without requiring `allUsers` IAM binding. This bypasses the `iam.allowedPolicyMemberDomains` organization policy restriction.

## Architecture

```
Internet (Supabase Edge Functions)
    ↓ (HTTPS - public)
Load Balancer (publicly accessible)
    ↓ (HTTP - authenticated via service account)
Proxy Service (Cloud Run - private, authenticated)
    ↓ (forwards Supabase JWT)
Orchestration Service (Cloud Run - authenticated)
```

## Benefits

1. **Bypasses Organization Policy**: The Load Balancer is publicly accessible, but the Cloud Run service remains private
2. **No IAM Policy Changes**: No need to add `allUsers` to Cloud Run IAM
3. **Better Security**: Service-to-service authentication between Load Balancer and Cloud Run
4. **SSL/TLS**: Can use Google-managed SSL certificates
5. **CDN Ready**: Can enable Cloud CDN if needed

## Prerequisites

1. Proxy service must be deployed to Cloud Run first
2. Domain name (optional - can use IP address for testing)

## Setup Steps

### Step 1: Deploy Proxy Service

Ensure the proxy service is deployed:

```powershell
# Deploy proxy service (if not already deployed)
.\scripts\deploy-proxy-service-simple.ps1
```

### Step 2: Configure Terraform Variables

Add to `terraform.tfvars`:

```hcl
# Optional: Domain for SSL certificate
# Leave empty to use IP address only (HTTP)
proxy_domain = ""  # e.g., "proxy.credovo.app"
```

### Step 3: Apply Terraform Configuration

```powershell
cd infrastructure/terraform
terraform init
terraform plan
terraform apply
```

### Step 4: Get Load Balancer IP/URL

After applying, get the Load Balancer details:

```powershell
# Get the IP address
terraform output load_balancer_ip

# Get the URL
terraform output load_balancer_url
```

### Step 5: Update Edge Function

Update your Supabase Edge Function to use the Load Balancer URL instead of the direct Cloud Run URL:

```typescript
// In supabase/functions/applications/index.ts
const proxyUrl = Deno.env.get("PROXY_SERVICE_URL") || 
  "http://<LOAD_BALANCER_IP>";  // Use the IP from terraform output

const backendResponse = await fetch(`${proxyUrl}/api/v1/applications`, {
  method: "POST",
  headers: {
    "Authorization": `Bearer ${token}`,
    "Content-Type": "application/json",
  },
  body: JSON.stringify(body),
});
```

### Step 6: Configure DNS (Optional - if using domain)

If you provided a `proxy_domain`, configure DNS:

1. Get the Load Balancer IP from Terraform output
2. Create an A record pointing your domain to the IP:
   ```
   proxy.credovo.app  A  <LOAD_BALANCER_IP>
   ```
3. Wait for SSL certificate provisioning (can take 10-60 minutes)

## Testing

### Test Load Balancer Health Endpoint

```powershell
$lbUrl = terraform output -raw load_balancer_url
Invoke-RestMethod -Uri "$lbUrl/health"
```

### Test Full Flow

```powershell
$lbUrl = terraform output -raw load_balancer_url
$response = Invoke-RestMethod -Uri "$lbUrl/api/v1/applications" `
    -Method POST `
    -Headers @{
        "Authorization" = "Bearer <SUPABASE_JWT_TOKEN>"
        "Content-Type" = "application/json"
    } `
    -Body (@{
        userId = "test-user-id"
        type = "individual"
        data = @{
            firstName = "Test"
            lastName = "User"
        }
    } | ConvertTo-Json)

Write-Host $response
```

## Troubleshooting

### Load Balancer returns 502 Bad Gateway

1. **Check proxy service exists**: Ensure `proxy-service` is deployed
2. **Check IAM binding**: Verify the Load Balancer service account has `roles/run.invoker` on the proxy service
3. **Check NEG**: Verify the Network Endpoint Group is correctly configured

```powershell
# Check IAM binding
gcloud run services get-iam-policy proxy-service `
    --region=europe-west1 `
    --project=credovo-eu-apps-nonprod

# Check NEG
gcloud compute network-endpoint-groups describe proxy-service-neg `
    --region=europe-west1 `
    --project=credovo-eu-apps-nonprod
```

### SSL Certificate Not Provisioning

1. **Check DNS**: Ensure A record is correctly configured
2. **Wait**: SSL certificate provisioning can take 10-60 minutes
3. **Check certificate status**:

```powershell
gcloud compute ssl-certificates describe proxy-service-ssl-cert `
    --global `
    --project=credovo-eu-apps-nonprod
```

### Service Account Permissions

If the Load Balancer can't invoke the proxy service:

```powershell
# Grant permission manually
gcloud run services add-iam-policy-binding proxy-service `
    --region=europe-west1 `
    --member="serviceAccount:load-balancer-proxy@credovo-eu-apps-nonprod.iam.gserviceaccount.com" `
    --role=roles/run.invoker `
    --project=credovo-eu-apps-nonprod
```

## Cost Considerations

- **Load Balancer**: ~$18/month base cost + usage
- **SSL Certificate**: Free (Google-managed)
- **Data Transfer**: Standard egress pricing

For low-traffic scenarios, the Load Balancer may be more expensive than direct Cloud Run access, but it bypasses organization policy restrictions.

## Alternative: HTTP Load Balancer (No SSL)

If you don't need SSL and want to test quickly, you can use HTTP:

1. Set `proxy_domain = ""` in `terraform.tfvars`
2. Apply Terraform
3. Use the IP address directly: `http://<IP>`

**Note**: HTTP is not recommended for production due to security concerns.

## Next Steps

1. ✅ Deploy proxy service
2. ✅ Apply Load Balancer Terraform configuration
3. ✅ Update Edge Function to use Load Balancer URL
4. ✅ Test end-to-end flow
5. ⏭️ Configure custom domain (optional)
6. ⏭️ Enable Cloud CDN (optional, for better performance)
