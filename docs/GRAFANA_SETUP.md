# Grafana Dashboard Setup for Credovo Platform

This guide explains how to set up Grafana to monitor Credovo applications across all production regions.

## Overview

The Grafana dashboard provides comprehensive monitoring of:
- **Applications**: KYC/KYB initiation and completion rates
- **Service Health**: Request counts, latency (p95), error rates, instance counts
- **Webhook Activity**: Webhooks received vs failed
- **AML Screening**: AML screening events
- **Multi-Region Support**: Filter by project/region (UK, UAE, US, EU)

## Prerequisites

1. **Grafana Instance**: Grafana 8.0+ (can be self-hosted or Grafana Cloud)
2. **Google Cloud Monitoring Plugin**: Installed and configured
3. **GCP Service Account**: With Monitoring Viewer permissions
4. **GCP Projects**: Access to all regional projects:
   - `credovo-uk-apps-prod` (UK)
   - `credovo-uae-apps-prod` (UAE)
   - `credovo-us-apps-prod` (US)
   - `credovo-eu-apps-prod` (EU)

## Setup Steps

### 1. Install Grafana (if not already installed)

#### Option A: Grafana Cloud (Recommended)
1. Sign up at [grafana.com](https://grafana.com)
2. Create a new stack
3. Note your Grafana URL and API key

#### Option B: Self-Hosted
```bash
# Docker
docker run -d -p 3000:3000 --name=grafana grafana/grafana

# Or using Helm (Kubernetes)
helm repo add grafana https://grafana.github.io/helm-charts
helm install grafana grafana/grafana
```

### 2. Install Google Cloud Monitoring Plugin

1. In Grafana UI, go to **Configuration → Plugins**
2. Search for "Google Cloud Monitoring"
3. Click **Install**
4. Enable the plugin

### 3. Configure Google Cloud Monitoring Data Source

1. Go to **Configuration → Data Sources**
2. Click **Add data source**
3. Select **Google Cloud Monitoring**
4. Configure:
   - **Name**: `Google Cloud Monitoring`
   - **Authentication**: Choose one:
     - **JWT File**: Upload service account JSON key
     - **GCE Default Service Account**: If running on GCE/GKE
     - **API Key**: Use API key (less secure)
   
5. **Service Account Setup**:
   ```bash
   # Create service account with Monitoring Viewer role
   gcloud iam service-accounts create grafana-monitoring \
     --display-name="Grafana Monitoring"
   
   gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
     --member="serviceAccount:grafana-monitoring@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
     --role="roles/monitoring.viewer"
   
   # Create and download key
   gcloud iam service-accounts keys create grafana-key.json \
     --iam-account=grafana-monitoring@YOUR_PROJECT_ID.iam.gserviceaccount.com
   ```
   
6. Upload the JSON key file in Grafana
7. Click **Save & Test**

### 4. Import Dashboard

1. Go to **Dashboards → Import**
2. Click **Upload JSON file**
3. Select `infrastructure/grafana/credovo-dashboard.json`
4. Configure:
   - **Name**: Credovo Platform - Multi-Region Applications Dashboard
   - **Folder**: Create "Credovo" folder
   - **Data Source**: Select "Google Cloud Monitoring"
5. Click **Import**

### 5. Configure Multi-Region Access

To monitor multiple regions, you need to:

1. **Add Multiple Data Sources** (one per region):
   - `Google Cloud Monitoring - UK`
   - `Google Cloud Monitoring - UAE`
   - `Google Cloud Monitoring - US`
   - `Google Cloud Monitoring - EU`

2. **Or Use Single Data Source with Cross-Project Queries**:
   - Ensure service account has access to all projects
   - Use project variable in dashboard

### 6. Customize Dashboard Variables

The dashboard includes variables for filtering:

- **Project/Region**: Select which GCP projects to monitor
- **Service**: Filter by service name (orchestration-service, kyc-kyb-service, etc.)

To update project list:
1. Edit dashboard
2. Go to **Variables** section
3. Edit `project` variable
4. Update query to include all regional projects:
   ```
   label_values(resource.label.project_id, resource.label.project_id)
   ```

## Dashboard Panels

### 1. Request Count by Service
- Shows total requests per service over time
- Helps identify traffic patterns and peak times

### 2. Request Latency (p95) by Service
- 95th percentile latency
- Thresholds: Green < 1s, Yellow 1-5s, Red > 5s

### 3. Error Rate (5xx) by Service
- Tracks 5xx errors
- Thresholds: Green = 0, Yellow ≥ 1, Red ≥ 5

### 4. Instance Count by Service
- Number of running Cloud Run instances
- Helps with capacity planning

### 5. KYC Applications - Initiated vs Completed
- Tracks KYC verification flow
- Shows completion rate over time

### 6. KYB Applications - Initiated vs Completed
- Tracks KYB verification flow
- Shows completion rate over time

### 7. Webhook Activity
- Webhooks received vs failed
- Critical for async verification processing

### 8. AML Screening Activity
- AML screening events over time
- Compliance and risk monitoring

## Advanced Configuration

### Add Custom Metrics

To add new metrics to the dashboard:

1. Ensure metric exists in Cloud Monitoring (see `infrastructure/terraform/monitoring.tf`)
2. Edit dashboard
3. Add new panel
4. Use MQL (Monitoring Query Language):
   ```
   fetch cloud_run_revision
   | filter metric.type = "logging.googleapis.com/user/YOUR_METRIC"
   | group_by 1m, [value_sum: sum(value.YOUR_METRIC)]
   | every 1m
   ```

### Set Up Alerts

1. In Grafana, go to **Alerting → Alert Rules**
2. Create new rule
3. Use dashboard panels as alert conditions
4. Configure notification channels (email, Slack, PagerDuty)

### Multi-Region Aggregation

To aggregate metrics across all regions:

1. Create new panel
2. Use multiple queries (one per region)
3. Use transformations to combine data
4. Example: Total applications across all regions

## Troubleshooting

### No Data Showing

1. **Check Data Source Connection**:
   - Test connection in data source settings
   - Verify service account has correct permissions

2. **Check Metric Availability**:
   - Ensure log-based metrics are created (see `monitoring.tf`)
   - Wait 10-15 minutes after metric creation

3. **Check Time Range**:
   - Ensure time range includes data
   - Try "Last 24 hours" or "Last 7 days"

4. **Check Project Filter**:
   - Verify project variable includes correct projects
   - Check service account has access to all projects

### Permission Errors

```bash
# Grant Monitoring Viewer to service account for all projects
for project in credovo-uk-apps-prod credovo-uae-apps-prod credovo-us-apps-prod credovo-eu-apps-prod; do
  gcloud projects add-iam-policy-binding $project \
    --member="serviceAccount:grafana-monitoring@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/monitoring.viewer"
done
```

### Metric Not Found

1. Check if metric exists:
   ```bash
   gcloud logging metrics describe kyc_initiated
   ```

2. Verify metric filter matches log format:
   ```bash
   gcloud logging read "resource.type=cloud_run_revision AND jsonPayload.event=kyc_initiated" --limit 5
   ```

## Best Practices

1. **Regular Updates**: Keep dashboard updated with new metrics
2. **Documentation**: Document custom panels and their purpose
3. **Access Control**: Use Grafana teams/roles to control access
4. **Backup**: Export dashboard JSON regularly
5. **Performance**: Limit time ranges for large datasets
6. **Alerting**: Set up alerts for critical metrics

## Additional Resources

- [Grafana Documentation](https://grafana.com/docs/)
- [Google Cloud Monitoring Plugin](https://grafana.com/docs/grafana/latest/datasources/google-cloud-monitoring/)
- [MQL Reference](https://cloud.google.com/monitoring/mql)
- [Cloud Monitoring API](https://cloud.google.com/monitoring/api/v3)

## Support

For issues or questions:
1. Check Grafana logs
2. Review Cloud Monitoring metrics directly
3. Verify service account permissions
4. Check Terraform monitoring configuration
