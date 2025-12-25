terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  backend "gcs" {
    bucket = "credovo-terraform-state"
    prefix = "terraform/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "run.googleapis.com",
    "storage.googleapis.com",
    "bigquery.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudtasks.googleapis.com",
    "pubsub.googleapis.com",
    "sqladmin.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
    "vpcaccess.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com"
  ])

  project = var.project_id
  service = each.value

  disable_dependent_services = false
  disable_on_destroy         = false
}

# Service accounts for each microservice
resource "google_service_account" "services" {
  for_each = toset([
    "kyc-kyb-service",
    "connector-service",
    "orchestration-service",
    "aml-fraud-service",
    "credit-income-service",
    "affordability-service",
    "avm-service",
    "payment-service",
    "legal-service"
  ])

  account_id   = each.value
  display_name = "${each.value} Service Account"
  description  = "Service account for ${each.value}"
}

# Grant service accounts necessary permissions
resource "google_project_iam_member" "service_account_permissions" {
  for_each = {
    for svc in google_service_account.services : svc.account_id => svc
  }

  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${each.value.email}"
}

resource "google_project_iam_member" "service_account_storage" {
  for_each = {
    for svc in google_service_account.services : svc.account_id => svc
  }

  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${each.value.email}"
}

resource "google_project_iam_member" "service_account_pubsub" {
  for_each = {
    for svc in google_service_account.services : svc.account_id => svc
  }

  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${each.value.email}"
}

resource "google_project_iam_member" "service_account_bigquery" {
  for_each = {
    for svc in google_service_account.services : svc.account_id => svc
  }

  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${each.value.email}"
}

# Artifact Registry for Docker images
resource "google_artifact_registry_repository" "docker_repo" {
  location      = var.region
  repository_id = "credovo-services"
  description   = "Docker repository for Credovo services"
  format        = "DOCKER"
}

# VPC Connector for Cloud Run
resource "google_vpc_access_connector" "cloud_run_connector" {
  name          = "credovo-vpc-connector"
  region        = var.region
  network       = "default"
  ip_cidr_range = "10.8.0.0/28"
  
  min_instances = 2
  max_instances = 3
  machine_type  = "e2-micro"
}


