# Grafana Dashboard for Credovo Platform

This directory contains Grafana dashboard configurations for monitoring Credovo applications across all production regions.

## Files

- `credovo-dashboard.json` - Main Grafana dashboard JSON (import this into Grafana)
- `dashboard.json` - Alternative dashboard format (for reference)

## Quick Start

1. **Set up Grafana** (see [GRAFANA_SETUP.md](../../docs/GRAFANA_SETUP.md))
2. **Configure Google Cloud Monitoring data source**
3. **Import `credovo-dashboard.json`** into Grafana
4. **Configure project/region variables** to include all production projects

## Dashboard Features

### Multi-Region Support
- Filter by GCP project (UK, UAE, US, EU)
- Aggregate metrics across regions
- Region-specific service health monitoring

### Application Metrics
- KYC/KYB initiation and completion rates
- Success rates and trends
- Application volume over time

### Service Health
- Request counts and patterns
- Latency (p95) with thresholds
- Error rates (5xx)
- Instance counts

### Operational Metrics
- Webhook activity (received vs failed)
- AML screening events
- Data lake storage health

## Customization

### Adding New Metrics

1. Ensure metric exists in Cloud Monitoring (see `../terraform/monitoring.tf`)
2. Edit dashboard JSON
3. Add new panel with MQL query:
   ```json
   {
     "targets": [{
       "refId": "A",
       "queryType": "metrics",
       "metricQuery": {
         "projectId": "$project",
         "query": "fetch cloud_run_revision\n| filter metric.type = \"logging.googleapis.com/user/YOUR_METRIC\"\n| group_by 1m, [value_sum: sum(value.YOUR_METRIC)]\n| every 1m"
       }
     }]
   }
   ```

### Updating Project List

Edit the `project` variable in dashboard JSON:
```json
{
  "name": "project",
  "query": "label_values(resource.label.project_id, resource.label.project_id)",
  "includeAll": true
}
```

## Maintenance

- **Version Control**: Dashboard JSON is version controlled
- **Backup**: Export dashboard regularly from Grafana UI
- **Updates**: Update dashboard when adding new services or metrics
- **Documentation**: Keep [GRAFANA_SETUP.md](../../docs/GRAFANA_SETUP.md) updated

## Related Documentation

- [GRAFANA_SETUP.md](../../docs/GRAFANA_SETUP.md) - Complete setup guide
- [MONITORING_SETUP.md](../../docs/MONITORING_SETUP.md) - Cloud Monitoring setup
- [monitoring.md](../../docs/monitoring.md) - Monitoring overview
