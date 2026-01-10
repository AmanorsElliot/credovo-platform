# Monitoring and Alerting Setup

This document describes the comprehensive monitoring and alerting setup for the Credovo platform.

## Overview

The monitoring system uses Google Cloud Monitoring to track:
- Service health and performance
- KYC/KYB verification flows
- Webhook processing
- Data lake storage
- Error rates and failures

## Alert Policies

### 1. High Error Rate
**Trigger**: More than 5 5xx errors in 5 minutes  
**Services**: All Cloud Run services  
**Action**: Investigate service errors

### 2. High Latency
**Trigger**: p95 latency exceeds 5 seconds for 5 minutes  
**Services**: All Cloud Run services  
**Action**: Check for performance bottlenecks

### 3. Service Unavailable
**Trigger**: Service instance count drops below 1  
**Services**: All Cloud Run services  
**Action**: Service may be down - immediate investigation required

### 4. Webhook Processing Failures
**Trigger**: More than 3 webhook failures in 5 minutes  
**Services**: Orchestration service  
**Action**: Check webhook handler logs, verify Shufti Pro connectivity

### 5. Missing Webhooks (Optional)
**Trigger**: No webhook activity for 30 minutes  
**Services**: Orchestration service  
**Status**: Disabled by default (enable if expecting regular webhooks)  
**Action**: Verify Shufti Pro is sending webhooks

### 6. High KYC/KYB Failure Rate
**Trigger**: More than 3 KYC/KYB service failures in 5 minutes  
**Services**: KYC/KYB service  
**Action**: Check verification provider connectivity, review error logs

### 7. Data Lake Storage Failures
**Trigger**: More than 2 storage write failures in 5 minutes  
**Services**: All services  
**Action**: Check GCS bucket permissions, storage quota

### 8. Connector Service Failures
**Trigger**: More than 3 connector service errors in 5 minutes  
**Services**: Connector service  
**Action**: Check external provider connectivity (Shufti Pro, etc.)

## Custom Metrics

### Log-Based Metrics

These metrics are extracted from application logs:

1. **KYC Initiated** (`kyc_initiated`)
   - Tracks KYC verification initiations
   - Filter: `jsonPayload.event="kyc_initiated"`

2. **KYC Completed** (`kyc_completed`)
   - Tracks completed KYC verifications
   - Filter: `jsonPayload.event="kyc_completed"`

3. **KYB Initiated** (`kyb_initiated`)
   - Tracks KYB verification initiations
   - Filter: `jsonPayload.event="kyb_initiated"`

4. **KYB Completed** (`kyb_completed`)
   - Tracks completed KYB verifications
   - Filter: `jsonPayload.event="kyb_completed"`

5. **Webhook Received** (`webhook_received`)
   - Tracks incoming webhooks from Shufti Pro
   - Filter: `textPayload=~"Received Shufti Pro webhook"`

6. **Webhook Failed** (`webhook_failed`)
   - Tracks webhook processing failures
   - Filter: `textPayload=~"webhook" AND (severity="ERROR" OR severity="WARNING")`

7. **AML Screening** (`aml_screening`)
   - Tracks AML screening events
   - Filter: `jsonPayload.aml!="" OR jsonPayload.risk_assessment!=""`

## Dashboards

### Credovo Cloud Run Services Dashboard

**Location**: Cloud Monitoring → Dashboards → "Credovo Cloud Run Services"

**Widgets**:
1. **Request Count (All Services)**: Total requests across all services
2. **Request Latency (p95)**: 95th percentile latency by service
3. **Error Rate (5xx)**: 5xx error rate by service
4. **Instance Count**: Running instances by service
5. **KYC/KYB Events**: Initiation and completion events
6. **Webhook Activity**: Webhooks received vs failures
7. **Requests by Service**: Breakdown of requests per service
8. **AML Screening Activity**: AML screening events over time

## Notification Channels

### Email Notifications
- **Default**: Email alerts sent to configured address
- **Configuration**: Set `alert_email_address` in `terraform.tfvars`

### Optional Channels
- **Slack**: Uncomment and configure in `notification-channels.tf`
- **PagerDuty**: Uncomment and configure in `notification-channels.tf`

## Setup Instructions

### 1. Configure Email Alerts

Edit `infrastructure/terraform/terraform.tfvars`:
```hcl
alert_email_address = "your-email@example.com"
```

### 2. Deploy Monitoring Infrastructure

```bash
cd infrastructure/terraform
terraform init
terraform plan
terraform apply
```

### 3. Verify Alerts

1. Go to [Cloud Monitoring → Alerting](https://console.cloud.google.com/monitoring/alerting)
2. Verify all alert policies are created
3. Test alerts by temporarily triggering conditions

### 4. View Dashboards

1. Go to [Cloud Monitoring → Dashboards](https://console.cloud.google.com/monitoring/dashboards)
2. Open "Credovo Cloud Run Services" dashboard
3. Customize as needed

## Log Queries

### View Service Logs
```bash
# All services
gcloud logging read "resource.type=cloud_run_revision" --limit=50 --project=credovo-eu-apps-nonprod

# Specific service
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=orchestration-service" --limit=50 --project=credovo-eu-apps-nonprod
```

### View Errors
```bash
gcloud logging read "severity>=ERROR" --limit=50 --project=credovo-eu-apps-nonprod
```

### View Webhook Activity
```bash
gcloud logging read "resource.type=cloud_run_revision AND textPayload=~'webhook'" --limit=50 --project=credovo-eu-apps-nonprod
```

### View KYC/KYB Events
```bash
gcloud logging read "jsonPayload.event=~'kyc|kyb'" --limit=50 --project=credovo-eu-apps-nonprod
```

## Alert Thresholds

Current thresholds are set for development/non-production. For production, consider:

- **Error Rate**: Lower threshold (e.g., 2-3 errors)
- **Latency**: Stricter threshold (e.g., 3 seconds)
- **Webhook Failures**: Lower threshold (e.g., 1-2 failures)
- **Service Availability**: More aggressive monitoring

## Best Practices

1. **Review Alerts Regularly**: Check alert history and adjust thresholds
2. **Set Up Escalation**: Configure PagerDuty or similar for critical alerts
3. **Monitor Trends**: Use dashboards to identify patterns
4. **Test Alerts**: Periodically test alert delivery
5. **Document Runbooks**: Create runbooks for common alert scenarios

## Troubleshooting

### Alerts Not Firing
- Check notification channel configuration
- Verify alert policy is enabled
- Check metric filters match log format

### Too Many Alerts
- Adjust thresholds in `monitoring.tf`
- Review alert conditions
- Consider alert grouping

### Missing Metrics
- Verify log format matches metric filters
- Check log-based metrics are created
- Review application logging

## References

- [Cloud Monitoring Documentation](https://cloud.google.com/monitoring/docs)
- [Alerting Policies](https://cloud.google.com/monitoring/alerts)
- [Log-based Metrics](https://cloud.google.com/logging/docs/logs-based-metrics)
- [Dashboards](https://cloud.google.com/monitoring/dashboards)

