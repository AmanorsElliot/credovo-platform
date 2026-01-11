# Scripts

Utility scripts for the Credovo platform.

## Essential Scripts

### Testing
- **`test-comprehensive.ps1`** - Comprehensive end-to-end test suite
- **`test-integration.ps1`** - Integration test suite

### Configuration
- **`configure-plaid-secrets.ps1`** - Configure Plaid credentials in Secret Manager
- **`get-test-token.ps1`** - Get authentication token for testing

### Deployment (One-time Setup)
- **`setup-grafana.ps1`** - Set up Grafana on GCP (production only)
- **`configure-grafana-alerts.ps1`** - Configure Grafana alerts

## Usage

### Run Tests
```powershell
.\scripts\test-comprehensive.ps1
.\scripts\test-integration.ps1
```

### Configure Secrets
```powershell
.\scripts\configure-plaid-secrets.ps1 -ProjectId "credovo-eu-apps-nonprod"
```

### Get Test Token
```powershell
.\scripts\get-test-token.ps1
```

## Notes

- Most scripts require `gcloud` CLI to be installed and authenticated
- Scripts are designed for Windows PowerShell
- See individual script files for detailed usage instructions
