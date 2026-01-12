# Load Balancer Quick Start

## Why Use a Load Balancer?

The organization policy `iam.allowedPolicyMemberDomains` blocks adding `allUsers` to Cloud Run IAM policies. A Load Balancer solves this by:
- Making the **Load Balancer** publicly accessible (no organization policy restrictions)
- Keeping the **Cloud Run service** private (authenticated via service account)
- Bypassing the organization policy entirely

## Quick Setup (5 minutes)

### 1. Ensure Proxy Service is Deployed

```powershell
# Check if proxy service exists
gcloud run services describe proxy-service `
    --region=europe-west1 `
    --project=credovo-eu-apps-nonprod
```

If it doesn't exist, deploy it first:
```powershell
.\scripts\deploy-proxy-service-simple.ps1
```

### 2. Apply Terraform Configuration

```powershell
cd infrastructure/terraform

# Initialize (if first time)
terraform init

# Review changes
terraform plan

# Apply
terraform apply
```

### 3. Get the Load Balancer URL

```powershell
# Get IP address
terraform output load_balancer_ip

# Get full URL
terraform output load_balancer_url
```

### 4. Update Edge Function

Update your Supabase Edge Function environment variable:
```
PROXY_SERVICE_URL=http://<LOAD_BALANCER_IP>
```

Or if using a domain:
```
PROXY_SERVICE_URL=https://proxy.credovo.app
```

### 5. Test

```powershell
$lbUrl = terraform output -raw load_balancer_url
Invoke-RestMethod -Uri "$lbUrl/health"
```

## Architecture

```
┌─────────────────────┐
│ Supabase Edge Func  │
│  (Public Internet)  │
└──────────┬──────────┘
           │ HTTPS (public)
           ↓
┌─────────────────────┐
│  Load Balancer      │
│  (Public IP/Domain) │
└──────────┬──────────┘
           │ HTTP (authenticated)
           ↓
┌─────────────────────┐
│  Proxy Service      │
│  (Cloud Run -       │
│   Private)          │
└──────────┬──────────┘
           │
           ↓
┌─────────────────────┐
│ Orchestration       │
│ Service             │
└─────────────────────┘
```

## Key Benefits

✅ **Bypasses Organization Policy** - No need for `allUsers` IAM binding  
✅ **Better Security** - Service-to-service authentication  
✅ **SSL/TLS Support** - Google-managed certificates  
✅ **Production Ready** - Standard GCP pattern  

## Cost

- **Base Cost**: ~$18/month for Load Balancer
- **Data Transfer**: Standard egress pricing
- **SSL Certificate**: Free (Google-managed)

## Next Steps

See [LOAD_BALANCER_SETUP.md](./LOAD_BALANCER_SETUP.md) for detailed configuration, troubleshooting, and advanced options.
