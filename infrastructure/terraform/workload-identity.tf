# Workload Identity Federation for GitHub Actions
# This creates the provider that the CLI/Console is having trouble with
# Note: The pool "github-actions-pool-v2" must already exist

# Get project number for principal format
data "google_project" "project" {
  project_id = var.project_id
}

# Create the provider
# NOTE: This is currently failing due to organization policy requiring attribute conditions
# The provider must be created manually via GCP Console or API with proper condition configuration
# Uncomment and configure once the provider is created manually
#
# resource "google_iam_workload_identity_pool_provider" "github_provider" {
#   workload_identity_pool_id          = "github-actions-pool-v2"
#   workload_identity_pool_provider_id = "github-provider"
#   display_name                        = "GitHub Provider"
#   project                             = var.project_id
#   
#   attribute_mapping = {
#     "google.subject" = "assertion.sub"
#   }
#   
#   oidc {
#     issuer_uri = "https://token.actions.githubusercontent.com"
#   }
#   
#   depends_on = [time_sleep.wait_for_apis]
# }

# Use existing github-actions service account (already created)
data "google_service_account" "github_actions" {
  account_id = "github-actions"
  project    = var.project_id
}

# Grant GitHub Actions permission to impersonate the service account
# Note: The Workload Identity Pool and Provider must be created manually (see docs/WORKLOAD_IDENTITY_MANUAL_SETUP.md)
# The provider was created with attribute condition: assertion.repository == "AmanorsElliot/credovo-platform"
# Format: principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/POOL_ID/attribute.ATTRIBUTE_NAME/ATTRIBUTE_VALUE
# Must include attribute path to match the provider's condition
resource "google_service_account_iam_member" "github_actions_workload_identity" {
  service_account_id = data.google_service_account.github_actions.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/projects/${data.google_project.project.number}/locations/global/workloadIdentityPools/github-actions-pool-v2/attribute.repository/AmanorsElliot/credovo-platform"
  
  # No depends_on needed - the provider exists manually and IAM binding works independently
}

