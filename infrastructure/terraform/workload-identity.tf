# Workload Identity Federation for GitHub Actions
# This creates the provider that the CLI/Console is having trouble with
# Note: The pool "github-actions-pool-v2" must already exist

# Get project number for principal format
data "google_project" "project" {
  project_id = var.project_id
}

# Create the provider
resource "google_iam_workload_identity_pool_provider" "github_provider" {
  workload_identity_pool_id          = "github-actions-pool-v2"
  workload_identity_pool_provider_id = "github-provider"
  display_name                        = "GitHub Provider"
  project                             = var.project_id
  
  attribute_mapping = {
    "google.subject" = "assertion.sub"
  }
  
  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
  
  depends_on = [time_sleep.wait_for_apis]
}

# Create github-actions service account if it doesn't exist in the services map
resource "google_service_account" "github_actions" {
  account_id   = "github-actions"
  display_name = "GitHub Actions Service Account"
  description  = "Service account for GitHub Actions CI/CD"
  project      = var.project_id
}

# Grant GitHub Actions permission to impersonate the service account
# Use principalSet for all principals in the pool (simpler)
resource "google_service_account_iam_member" "github_actions_workload_identity" {
  service_account_id = google_service_account.github_actions.name
  role               = "roles/iam.workloadIdentityUser"
  # Format: principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/POOL_ID
  member             = "principalSet://iam.googleapis.com/projects/${data.google_project.project.number}/locations/global/workloadIdentityPools/github-actions-pool-v2"
  
  depends_on = [google_iam_workload_identity_pool_provider.github_provider]
}

