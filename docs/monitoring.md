# Monitoring and Observability

> **Note**: For comprehensive monitoring setup, see [MONITORING_SETUP.md](MONITORING_SETUP.md)

## Overview

The platform includes comprehensive monitoring through Google Cloud Monitoring with:
- 7 alert policies for service health and errors
- 7 custom log-based metrics for KYC/KYB events
- Enhanced dashboard with 8 widgets
- Email notification channels

## Quick Reference

### Dashboards

- **Credovo Cloud Run Services Dashboard**: Overview of all microservices
  - Request count, latency (p95), error rate
  - Instance count
  - KYC/KYB events
  - Webhook activity
  - AML screening metrics

### Alert Policies

See [MONITORING_SETUP.md](MONITORING_SETUP.md) for complete list. Key alerts:
1. **High Error Rate**: 5xx errors > 5 in 5 minutes
2. **High Latency**: p95 latency > 5 seconds
3. **Service Unavailable**: Instance count < 1
4. **Webhook Failures**: Webhook processing failures
5. **KYC/KYB Failures**: Verification service errors
6. **Data Lake Storage Failures**: Storage write errors
7. **Connector Service Failures**: External API errors

### Custom Metrics

- `kyc_initiated`, `kyc_completed`: KYC process tracking
- `kyb_initiated`, `kyb_completed`: KYB process tracking
- `webhook_received`, `webhook_failed`: Webhook activity
- `aml_screening`: AML screening events
- `data_lake_storage_failures`: Storage error tracking

## Logging

All services use structured logging that integrates with Cloud Logging:

```typescript
logger.info('Event occurred', { 
  applicationId: 'xxx',
  userId: 'yyy',
  metadata: {}
});
```

### Log Queries

```bash
# View KYC service logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=kyc-kyb-service" --limit 50

# View errors
gcloud logging read "severity>=ERROR" --limit 50

# View specific application
gcloud logging read "jsonPayload.applicationId=xxx" --limit 50
```

## Distributed Tracing

OpenTelemetry can be added for distributed tracing across services. This would help identify:
- Request flow across services
- Performance bottlenecks
- Service dependencies

## Health Checks

All services expose health check endpoints:
- `/health` - Basic health check
- `/health/ready` - Readiness probe
- `/health/live` - Liveness probe

These can be used by Cloud Run for automatic health monitoring.

