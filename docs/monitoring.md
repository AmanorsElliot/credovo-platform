# Monitoring and Observability

## Cloud Monitoring

The platform includes comprehensive monitoring through Google Cloud Monitoring:

### Dashboards

- **Cloud Run Services Dashboard**: Overview of all microservices
  - Request count
  - Request latency (p95)
  - Error rate
  - Instance count

### Alert Policies

1. **High Error Rate**: Triggers when error rate exceeds threshold
2. **High Latency**: Triggers when p95 latency exceeds 5 seconds
3. **Service Unavailable**: Triggers when service instance count drops below 1

### Custom Metrics

- `kyc_initiated`: Tracks KYC process initiations
- `kyc_completed`: Tracks KYC process completions

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

