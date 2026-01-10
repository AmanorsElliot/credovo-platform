# Scripts Directory

This directory contains PowerShell scripts for managing the Credovo platform.

## Deployment Scripts

### `deploy-all-services.ps1`
Deploys all services to Cloud Run using Cloud Build.
```powershell
.\scripts\deploy-all-services.ps1
```

### `deploy-to-gcp.ps1`
Complete GCP deployment including infrastructure and services.
```powershell
.\scripts\deploy-to-gcp.ps1
```

### `deploy-shufti-secrets.ps1`
Deploys Shufti Pro secrets to Secret Manager using Terraform.
```powershell
.\scripts\deploy-shufti-secrets.ps1
```

## Configuration Scripts

### `configure-secrets-now.ps1`
Configures GCP Secret Manager secrets (Supabase, JWT, API keys).
```powershell
.\scripts\configure-secrets-now.ps1
```

### `setup-cloud-build-triggers.ps1`
Sets up Cloud Build triggers for automatic deployments.
```powershell
.\scripts\setup-cloud-build-triggers.ps1
```

## Package Management

### `publish-shared-types.ps1`
Builds and publishes `@amanorselliot/shared-types` npm package.
```powershell
# Dry run
.\scripts\publish-shared-types.ps1 -DryRun

# Publish to GitHub Packages
.\scripts\publish-shared-types.ps1 -Registry github

# Publish to npm
.\scripts\publish-shared-types.ps1 -Registry npm
```

## Frontend Setup

### `setup-separate-frontend-repo.ps1`
Helps set up the separate `credovo-webapp` repository for Lovable.
```powershell
.\scripts\setup-separate-frontend-repo.ps1
```

## Testing Scripts

### `test-backend-connection.ps1`
Tests backend service connectivity and endpoints.
```powershell
.\scripts\test-backend-connection.ps1
```

### `test-kyc-kyb-integration.ps1`
Tests KYC/KYB integration end-to-end.
```powershell
.\scripts\test-kyc-kyb-integration.ps1
```

## Utility Scripts

### `fix-authentication.ps1`
Helps fix GCP authentication issues.
```powershell
.\scripts\fix-authentication.ps1
```

## Notes

- All scripts use PowerShell and require `gcloud` CLI to be installed and authenticated
- Default project: `credovo-eu-apps-nonprod`
- Default region: `europe-west1`

