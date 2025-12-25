# Cloud Run service for KYC/KYB
resource "google_cloud_run_service" "kyc_kyb_service" {
  name     = "kyc-kyb-service"
  location = var.region

  template {
    spec {
      service_account_name = google_service_account.services["kyc-kyb-service"].email
      
      containers {
        # Use placeholder image initially - will be updated by CI/CD
        image = "gcr.io/cloudrun/hello"

        resources {
          limits = {
            cpu    = "1"
            memory = "512Mi"
          }
        }

        env {
          name  = "ENVIRONMENT"
          value = var.environment
        }

        env {
          name  = "PROJECT_ID"
          value = var.project_id
        }

        env {
          name  = "DATA_LAKE_BUCKET"
          value = google_storage_bucket.data_lake_raw.name
        }

        env {
          name  = "BIGQUERY_DATASET"
          value = google_bigquery_dataset.credovo_analytics.dataset_id
        }

        env {
          name = "LOVABLE_JWKS_URI"
          value_from {
            secret_key_ref {
              name = "lovable-jwks-uri"
              key  = "latest"
            }
          }
        }

        env {
          name = "LOVABLE_AUDIENCE"
          value_from {
            secret_key_ref {
              name = "lovable-audience"
              key  = "latest"
            }
          }
        }

        env {
          name = "SERVICE_JWT_SECRET"
          value_from {
            secret_key_ref {
              name = "service-jwt-secret"
              key  = "latest"
            }
          }
        }

        ports {
          container_port = 8080
        }
      }

      timeout_seconds = 300
    }

    metadata {
      annotations = {
        "autoscaling.knative.dev/minScale" = tostring(var.min_instances)
        "autoscaling.knative.dev/maxScale" = tostring(var.max_instances)
        "run.googleapis.com/vpc-access-connector" = google_vpc_access_connector.cloud_run_connector.name
        "run.googleapis.com/vpc-access-egress"    = "private-ranges-only"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  depends_on = [
    time_sleep.wait_for_apis,
    google_artifact_registry_repository.docker_repo
  ]
  
  lifecycle {
    # Ignore image changes - CI/CD will update the image
    ignore_changes = [template[0].spec[0].containers[0].image]
  }
}

# Cloud Run service for Connector Service
resource "google_cloud_run_service" "connector_service" {
  name     = "connector-service"
  location = var.region

  template {
    spec {
      service_account_name = google_service_account.services["connector-service"].email
      
      containers {
        # Use placeholder image initially - will be updated by CI/CD
        image = "gcr.io/cloudrun/hello"

        resources {
          limits = {
            cpu    = "1"
            memory = "512Mi"
          }
        }

        env {
          name  = "ENVIRONMENT"
          value = var.environment
        }

        env {
          name = "SERVICE_JWT_SECRET"
          value_from {
            secret_key_ref {
              name = "service-jwt-secret"
              key  = "latest"
            }
          }
        }

        ports {
          container_port = 8080
        }
      }

      timeout_seconds = 300
    }

    metadata {
      annotations = {
        "autoscaling.knative.dev/minScale" = tostring(var.min_instances)
        "autoscaling.knative.dev/maxScale" = tostring(var.max_instances)
        "run.googleapis.com/vpc-access-connector" = google_vpc_access_connector.cloud_run_connector.name
        "run.googleapis.com/vpc-access-egress"    = "private-ranges-only"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
  
  depends_on = [
    time_sleep.wait_for_apis,
    google_artifact_registry_repository.docker_repo
  ]
  
  lifecycle {
    # Ignore image changes - CI/CD will update the image
    ignore_changes = [template[0].spec[0].containers[0].image]
  }
}

# Cloud Run service for Orchestration Service
resource "google_cloud_run_service" "orchestration_service" {
  name     = "orchestration-service"
  location = var.region

  template {
    spec {
      service_account_name = google_service_account.services["orchestration-service"].email
      
      containers {
        # Use placeholder image initially - will be updated by CI/CD
        image = "gcr.io/cloudrun/hello"

        resources {
          limits = {
            cpu    = "2"
            memory = "1Gi"
          }
        }

        env {
          name  = "ENVIRONMENT"
          value = var.environment
        }

        env {
          name  = "KYC_SERVICE_URL"
          value = google_cloud_run_service.kyc_kyb_service.status[0].url
        }

        env {
          name  = "CONNECTOR_SERVICE_URL"
          value = google_cloud_run_service.connector_service.status[0].url
        }

        env {
          name = "LOVABLE_JWKS_URI"
          value_from {
            secret_key_ref {
              name = "lovable-jwks-uri"
              key  = "latest"
            }
          }
        }

        env {
          name = "LOVABLE_AUDIENCE"
          value_from {
            secret_key_ref {
              name = "lovable-audience"
              key  = "latest"
            }
          }
        }

        env {
          name = "SERVICE_JWT_SECRET"
          value_from {
            secret_key_ref {
              name = "service-jwt-secret"
              key  = "latest"
            }
          }
        }

        ports {
          container_port = 8080
        }
      }

      timeout_seconds = 300
    }

    metadata {
      annotations = {
        "autoscaling.knative.dev/minScale" = tostring(var.min_instances)
        "autoscaling.knative.dev/maxScale" = tostring(var.max_instances)
        "run.googleapis.com/vpc-access-connector" = google_vpc_access_connector.cloud_run_connector.name
        "run.googleapis.com/vpc-access-egress"    = "private-ranges-only"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
  
  depends_on = [
    time_sleep.wait_for_apis,
    google_artifact_registry_repository.docker_repo,
    google_cloud_run_service.kyc_kyb_service,
    google_cloud_run_service.connector_service
  ]
  
  lifecycle {
    # Ignore image changes - CI/CD will update the image
    ignore_changes = [template[0].spec[0].containers[0].image]
  }
}

# IAM policy to allow unauthenticated access (or use IAP for authenticated access)
resource "google_cloud_run_service_iam_member" "kyc_kyb_public_access" {
  service  = google_cloud_run_service.kyc_kyb_service.name
  location = google_cloud_run_service.kyc_kyb_service.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_service_iam_member" "orchestration_public_access" {
  service  = google_cloud_run_service.orchestration_service.name
  location = google_cloud_run_service.orchestration_service.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}


