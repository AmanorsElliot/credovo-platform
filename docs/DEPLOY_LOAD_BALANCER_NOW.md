# Deploy Load Balancer - Quick Guide

## Status
✅ Organization policy fixed - Load Balancer can now be created
✅ Terraform configuration ready in `infrastructure/terraform/load-balancer.tf`

## Quick Deploy Steps

### Option 1: Deploy Just the Load Balancer (Targeted)

If you have other Terraform errors, you can target just the Load Balancer resources:

```powershell
cd infrastructure\terraform

# Plan only Load Balancer resources
terraform plan -target=google_service_account.load_balancer `
    -target=google_cloud_run_service_iam_member.load_balancer_invoke_proxy `
    -target=google_compute_global_address.proxy_ip `
    -target=google_compute_region_network_endpoint_group.proxy_neg `
    -target=google_compute_backend_service.proxy_backend `
    -target=google_compute_url_map.proxy_url_map `
    -target=google_compute_target_https_proxy.proxy_https `
    -target=google_compute_target_http_proxy.proxy_http `
    -target=google_compute_global_forwarding_rule.proxy_https_forwarding `
    -target=google_compute_global_forwarding_rule.proxy_http_forwarding `
    -target=google_compute_managed_ssl_certificate.proxy_ssl `
    -out=tfplan-lb

# Apply
terraform apply tfplan-lb
```

### Option 2: Fix Other Errors First

If you want to fix the other Terraform errors first:

1. **Fix `grafana.tf` errors**: Remove `automatic = true` from secret resources
2. **Fix `main.tf` error**: Add `member` argument to `google_project_iam_member.service_account_permissions`

Then run:
```powershell
cd infrastructure\terraform
terraform plan
terraform apply
```

### Option 3: Use gcloud Commands Directly

If Terraform is problematic, you can create the Load Balancer using gcloud:

```powershell
# 1. Create service account
gcloud iam service-accounts create load-balancer-proxy `
    --display-name="Load Balancer Service Account" `
    --project=credovo-eu-apps-nonprod

# 2. Grant permission to invoke proxy service
gcloud run services add-iam-policy-binding proxy-service `
    --region=europe-west1 `
    --member="serviceAccount:load-balancer-proxy@credovo-eu-apps-nonprod.iam.gserviceaccount.com" `
    --role=roles/run.invoker `
    --project=credovo-eu-apps-nonprod

# 3. Reserve global IP
gcloud compute addresses create proxy-service-ip `
    --global `
    --project=credovo-eu-apps-nonprod

# 4. Create Network Endpoint Group
gcloud compute network-endpoint-groups create proxy-service-neg `
    --region=europe-west1 `
    --network-endpoint-type=serverless `
    --cloud-run-service=proxy-service `
    --project=credovo-eu-apps-nonprod

# 5. Create backend service
gcloud compute backend-services create proxy-service-backend `
    --global `
    --protocol=HTTP `
    --project=credovo-eu-apps-nonprod

# 6. Add NEG to backend service
gcloud compute backend-services add-backend proxy-service-backend `
    --global `
    --network-endpoint-group=proxy-service-neg `
    --network-endpoint-group-region=europe-west1 `
    --project=credovo-eu-apps-nonprod

# 7. Create URL map
gcloud compute url-maps create proxy-service-url-map `
    --default-service=proxy-service-backend `
    --project=credovo-eu-apps-nonprod

# 8. Create HTTP proxy (for testing without SSL)
gcloud compute target-http-proxies create proxy-service-http-proxy `
    --url-map=proxy-service-url-map `
    --project=credovo-eu-apps-nonprod

# 9. Create forwarding rule
$lbIp = gcloud compute addresses describe proxy-service-ip --global --format="value(address)" --project=credovo-eu-apps-nonprod
gcloud compute forwarding-rules create proxy-service-http-forwarding `
    --global `
    --target-http-proxy=proxy-service-http-proxy `
    --address=$lbIp `
    --ports=80 `
    --project=credovo-eu-apps-nonprod

# 10. Get the IP
Write-Host "Load Balancer IP: $lbIp" -ForegroundColor Cyan
Write-Host "Load Balancer URL: http://$lbIp" -ForegroundColor Cyan
```

## After Deployment

1. **Get the Load Balancer URL**:
   ```powershell
   $lbIp = gcloud compute addresses describe proxy-service-ip --global --format="value(address)" --project=credovo-eu-apps-nonprod
   Write-Host "http://$lbIp"
   ```

2. **Test the Load Balancer**:
   ```powershell
   .\scripts\test-load-balancer.ps1 -LoadBalancerUrl "http://$lbIp"
   ```

3. **Update Edge Function**:
   - Set `PROXY_SERVICE_URL=http://<IP>` in Supabase Edge Function environment variables

## Next Steps

Once the Load Balancer is deployed:
- ✅ Test connectivity
- ✅ Update Edge Function
- ✅ Test end-to-end flow
- ⏭️ Add HTTPS/SSL certificate (optional, if you have a domain)
