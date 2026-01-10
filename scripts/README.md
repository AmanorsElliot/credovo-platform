# Scripts Directory

This directory contains PowerShell scripts for managing the Credovo platform.

## Build & Deployment Scripts

### `setup-parallel-build-trigger.ps1`
Sets up a single Cloud Build trigger that builds all services in parallel. This is the recommended approach for faster builds.

```powershell
.\scripts\setup-parallel-build-trigger.ps1
```

### `disable-individual-triggers.ps1`
Removes individual service triggers after setting up the parallel build trigger to avoid duplicate builds.

```powershell
.\scripts\disable-individual-triggers.ps1
```

### `deploy-to-gcp.ps1`
Complete GCP deployment including infrastructure and services using Terraform.

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

### `grant-user-cloud-run-access.ps1`
Grants a specific user access to Cloud Run services for testing and development.

```powershell
.\scripts\grant-user-cloud-run-access.ps1
```

## Package Management

### `publish-shared-types.ps1`
Builds and publishes `@credovo/shared-types` npm package to GitHub Packages or npm.

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

### `copy-shared-types-to-webapp.ps1`
Copies shared types directly to credovo-webapp (useful when npm package can't be installed).

```powershell
.\scripts\copy-shared-types-to-webapp.ps1
```

## Testing Scripts

### `test-comprehensive.ps1`
Comprehensive end-to-end test suite for KYC/KYB flows, webhooks, and data lake storage.

```powershell
# Basic test run
.\scripts\test-comprehensive.ps1

# With authentication token
.\scripts\test-comprehensive.ps1 -AuthToken "your-supabase-jwt-token"

# Use gcloud authentication
.\scripts\test-comprehensive.ps1 -UseGcloudAuth

# Custom application ID
.\scripts\test-comprehensive.ps1 -ApplicationId "my-test-app-123"

# Skip webhook or data lake checks
.\scripts\test-comprehensive.ps1 -SkipWebhook -SkipDataLake
```

### `get-test-token.ps1`
Generates a test JWT token for testing API endpoints.

```powershell
.\scripts\get-test-token.ps1
```

## Build Management Scripts

### `cancel-stuck-builds.ps1`
Cancels Cloud Build builds that are stuck in QUEUED, WORKING, or PENDING status.

```powershell
.\scripts\cancel-stuck-builds.ps1
```

### `cancel-all-builds.ps1`
Bulk cancellation of Cloud Build builds (with limit).

```powershell
# Cancel up to 500 builds
.\scripts\cancel-all-builds.ps1

# Custom limit
.\scripts\cancel-all-builds.ps1 -Limit 100
```

### `cancel-builds-by-id.ps1`
Cancel specific Cloud Build builds by ID.

```powershell
.\scripts\cancel-builds-by-id.ps1
```

## Utility Scripts

### `fix-authentication.ps1`
Helps fix GCP authentication issues and grants necessary permissions.

```powershell
.\scripts\fix-authentication.ps1
```

## Notes

- All scripts use PowerShell and require `gcloud` CLI to be installed and authenticated
- Default project: `credovo-eu-apps-nonprod`
- Default region: `europe-west1`
- For Cloud Build triggers, use the parallel build trigger (`setup-parallel-build-trigger.ps1`) instead of individual service triggers
