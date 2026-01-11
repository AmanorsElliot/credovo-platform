# Service Accounts Reference

This document provides a clear reference for all service accounts used in the Credovo platform.

## Custom Service Accounts (User-Created)

These are service accounts we create with clear, descriptive names:

### Application Service Accounts

- **`proxy-service@credovo-eu-apps-nonprod.iam.gserviceaccount.com`**
  - **Purpose**: Proxy service that forwards requests from Edge Functions to orchestration service
  - **Permissions**: `roles/run.invoker` on orchestration-service
  - **Used by**: `proxy-service` Cloud Run service

- **`orchestration-service@credovo-eu-apps-nonprod.iam.gserviceaccount.com`**
  - **Purpose**: Main orchestration service
  - **Used by**: `orchestration-service` Cloud Run service

- **`kyc-kyb-service@credovo-eu-apps-nonprod.iam.gserviceaccount.com`**
  - **Purpose**: KYC/KYB verification service
  - **Used by**: `kyc-kyb-service` Cloud Run service

- **`connector-service@credovo-eu-apps-nonprod.iam.gserviceaccount.com`**
  - **Purpose**: External API connector service
  - **Used by**: `connector-service` Cloud Run service

- **`open-banking-service@credovo-eu-apps-nonprod.iam.gserviceaccount.com`**
  - **Purpose**: Open banking integration service
  - **Used by**: `open-banking-service` Cloud Run service

- **`company-search-service@credovo-eu-apps-nonprod.iam.gserviceaccount.com`**
  - **Purpose**: Company search service
  - **Used by**: `company-search-service` Cloud Run service

### CI/CD Service Accounts

- **`github-actions@credovo-eu-apps-nonprod.iam.gserviceaccount.com`**
  - **Purpose**: GitHub Actions workflow execution
  - **Permissions**: Cloud Build, Artifact Registry, Cloud Run deployment
  - **Used by**: GitHub Actions workflows

- **`cicd-deployer@credovo-eu-apps-nonprod.iam.gserviceaccount.com`**
  - **Purpose**: CI/CD pipeline deployments
  - **Permissions**: Cloud Run, Artifact Registry
  - **Used by**: CI/CD pipelines

## Google-Managed Service Accounts

These are automatically created by Google Cloud services. We reference them using variables to avoid hardcoding project numbers.

### Cloud Build Service Account

- **Format**: `{PROJECT_NUMBER}@cloudbuild.gserviceaccount.com`
- **Example**: `858440156644@cloudbuild.gserviceaccount.com`
- **Purpose**: Executes Cloud Build jobs
- **Permissions**: 
  - `roles/cloudbuild.builds.builder`
  - `roles/storage.admin` (for storing build artifacts)
  - `roles/artifactregistry.writer` (for pushing images)
  - `roles/run.admin` (for deploying to Cloud Run)

**How to reference in scripts:**
```powershell
$projectNumber = (gcloud projects describe credovo-eu-apps-nonprod --format="value(projectNumber)")
$cloudBuildSa = "$projectNumber@cloudbuild.gserviceaccount.com"
```

### Compute Engine Default Service Account

- **Format**: `{PROJECT_NUMBER}-compute@developer.gserviceaccount.com`
- **Example**: `858440156644-compute@developer.gserviceaccount.com`
- **Purpose**: Default service account for Compute Engine and Cloud Run source deployments
- **Permissions**:
  - `roles/storage.admin` (for source deployments)
  - `roles/artifactregistry.writer` (for pushing images)

**How to reference in scripts:**
```powershell
$projectNumber = (gcloud projects describe credovo-eu-apps-nonprod --format="value(projectNumber)")
$computeSa = "$projectNumber-compute@developer.gserviceaccount.com"
```

## Best Practices

1. **Always use variables** for Google-managed service accounts instead of hardcoding project numbers
2. **Use descriptive names** for custom service accounts (e.g., `proxy-service` not `sa-123`)
3. **Document service account purposes** in code comments and documentation
4. **Follow least privilege** - only grant necessary permissions
5. **Use service account email format**: `{name}@{project-id}.iam.gserviceaccount.com` for custom accounts

## Service Account Naming Convention

- **Format**: `{service-name}@{project-id}.iam.gserviceaccount.com`
- **Examples**:
  - ✅ `proxy-service@credovo-eu-apps-nonprod.iam.gserviceaccount.com`
  - ✅ `orchestration-service@credovo-eu-apps-nonprod.iam.gserviceaccount.com`
  - ❌ `sa-123@credovo-eu-apps-nonprod.iam.gserviceaccount.com` (unclear)
  - ❌ `858440156644@cloudbuild.gserviceaccount.com` (hardcoded number)

## Listing Service Accounts

```powershell
# List all custom service accounts
gcloud iam service-accounts list --project=credovo-eu-apps-nonprod

# Get project number for Google-managed accounts
gcloud projects describe credovo-eu-apps-nonprod --format="value(projectNumber)"
```
