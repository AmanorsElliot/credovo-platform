# Grafana deployment on GCP using Cloud Run
# This provides a managed Grafana instance accessible via HTTPS

# Service account for Grafana to access Cloud Monitoring
resource "google_service_account" "grafana_monitoring" {
  account_id   = "grafana-monitoring"
  display_name = "Grafana Monitoring Service Account"
  description  = "Service account for Grafana to access Google Cloud Monitoring"
}

# Grant Monitoring Viewer role to Grafana service account
resource "google_project_iam_member" "grafana_monitoring_viewer" {
  for_each = toset([
    var.project_id, # Current project
    # Add all regional projects
    "credovo-uk-apps-prod",
    "credovo-uae-apps-prod",
    "credovo-us-apps-prod",
    "credovo-eu-apps-prod"
  ])
  
  project = each.value
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.grafana_monitoring.email}"
}

# Service account key for Grafana (stored in Secret Manager)
resource "google_secret_manager_secret" "grafana_service_account_key" {
  secret_id = "grafana-service-account-key"
  
  replication {
    automatic = true
  }
}

# Note: Service account keys should be created manually and stored in Secret Manager
# This is because Terraform cannot export private keys directly
# Use the setup script to create and store the key

# Cloud Run service for Grafana
resource "google_cloud_run_service" "grafana" {
  name     = "grafana"
  location = var.region

  template {
    spec {
      containers {
        image = "grafana/grafana:latest"
        
        ports {
          container_port = 3000
        }

        env {
          name  = "GF_SERVER_ROOT_URL"
          value = "https://grafana.${var.domain}"
        }

        env {
          name  = "GF_SECURITY_ADMIN_USER"
          value = var.grafana_admin_user
        }

        env {
          name = "GF_SECURITY_ADMIN_PASSWORD"
          value_from {
            secret_key_ref {
              name = google_secret_manager_secret.grafana_admin_password.secret_id
              key  = "latest"
            }
          }
        }

        env {
          name  = "GF_INSTALL_PLUGINS"
          value = "grafana-google-cloud-monitoring-datasource"
        }

        env {
          name  = "GF_PLUGINS_ALLOW_LOADING_UNSIGNED_PLUGINS"
          value = "grafana-google-cloud-monitoring-datasource"
        }

        resources {
          limits = {
            cpu    = "2"
            memory = "2Gi"
          }
        }
      }

      service_account_name = google_service_account.grafana_monitoring.email
    }

    metadata {
      annotations = {
        "autoscaling.knative.dev/minScale" = "1"
        "autoscaling.knative.dev/maxScale" = "3"
        "run.googleapis.com/cloudsql-instances" = "" # Add if using Cloud SQL for persistence
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

# Secret for Grafana admin password
resource "google_secret_manager_secret" "grafana_admin_password" {
  secret_id = "grafana-admin-password"
  
  replication {
    automatic = true
  }
}

# Generate random password for Grafana admin
resource "random_password" "grafana_admin_password" {
  length  = 32
  special = true
}

# Store admin password in Secret Manager
resource "google_secret_manager_secret_version" "grafana_admin_password" {
  secret      = google_secret_manager_secret.grafana_admin_password.id
  secret_data = random_password.grafana_admin_password.result
}

# IAM policy to allow Cloud Run to access secrets
resource "google_secret_manager_secret_iam_member" "grafana_admin_password_access" {
  secret_id = google_secret_manager_secret.grafana_admin_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.grafana_monitoring.email}"
}

resource "google_secret_manager_secret_iam_member" "grafana_service_account_key_access" {
  secret_id = google_secret_manager_secret.grafana_service_account_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.grafana_monitoring.email}"
}

# Allow unauthenticated access (or configure IAP for production)
resource "google_cloud_run_service_iam_member" "grafana_public_access" {
  service  = google_cloud_run_service.grafana.name
  location = google_cloud_run_service.grafana.location
  role     = "roles/run.invoker"
  member   = "allUsers"
  
  # For production, use IAP instead:
  # member = "serviceAccount:${var.iap_service_account}"
}

# Outputs
output "grafana_url" {
  value       = google_cloud_run_service.grafana.status[0].url
  description = "URL of the Grafana instance"
}

output "grafana_admin_user" {
  value       = var.grafana_admin_user
  description = "Grafana admin username"
  sensitive   = true
}

output "grafana_service_account_email" {
  value       = google_service_account.grafana_monitoring.email
  description = "Service account email for Grafana"
}

output "grafana_service_account_key_secret" {
  value       = google_secret_manager_secret.grafana_service_account_key.secret_id
  description = "Secret Manager secret ID for Grafana service account key"
}
