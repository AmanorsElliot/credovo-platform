# Operations Guide

This guide covers operational tasks, monitoring, and troubleshooting.

## Monitoring

### Setup
- **[Monitoring Setup](MONITORING_SETUP.md)** - Complete monitoring and alerting setup
- **[Monitoring Overview](monitoring.md)** - Monitoring concepts and log queries

### Grafana (Production)
- **[Grafana Deployment](GRAFANA_DEPLOYMENT.md)** - Deploy Grafana on GCP
- **[Grafana Setup](GRAFANA_SETUP.md)** - Configure Grafana with Google Cloud Monitoring

**Note**: Grafana is configured but not deployed for nonprod. Deploy when ready for production.

## Testing

### Guides
- **[Testing Guide](TESTING_GUIDE.md)** - End-to-end testing instructions
- **[Test Auth Token](TEST_AUTH_TOKEN.md)** - How to get authentication tokens for testing

### Test Scripts
- `scripts/test-comprehensive.ps1` - Comprehensive end-to-end tests
- `scripts/test-integration.ps1` - Integration test suite

## Troubleshooting

### Build Issues
- **[Cloud Build Troubleshooting](CLOUD_BUILD_TROUBLESHOOTING.md)** - Common build issues and solutions

### Common Issues
1. **Build Failures**: Check [CLOUD_BUILD_TROUBLESHOOTING.md](CLOUD_BUILD_TROUBLESHOOTING.md)
2. **Authentication Errors**: See [AUTHENTICATION.md](AUTHENTICATION.md)
3. **Service Communication**: See [SERVICE_INTERACTIONS.md](SERVICE_INTERACTIONS.md)

## CI/CD

- **[Cloud Build Setup](CLOUD_BUILD_GITHUB_SETUP.md)** - Automated builds and deployments
- Builds automatically trigger on push to `main` branch
- All services build in parallel for faster deployment
