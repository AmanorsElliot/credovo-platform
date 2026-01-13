output "project_id" {
  description = "GCP Project ID"
  value       = var.project_id
}

output "region" {
  description = "GCP Region"
  value       = var.region
}

output "service_accounts" {
  description = "Service account emails"
  value = {
    for k, v in google_service_account.services : k => v.email
  }
}

output "artifact_registry" {
  description = "Artifact Registry repository name"
  value       = google_artifact_registry_repository.docker_repo.name
}

output "data_lake_raw_bucket" {
  description = "Data lake raw storage bucket"
  value       = google_storage_bucket.data_lake_raw.name
}

output "data_lake_archive_bucket" {
  description = "Data lake archive storage bucket"
  value       = google_storage_bucket.data_lake_archive.name
}

output "bigquery_dataset" {
  description = "BigQuery dataset for analytics"
  value       = google_bigquery_dataset.credovo_analytics.dataset_id
}

output "kyc_kyb_service_url" {
  description = "KYC/KYB service URL"
  value       = google_cloud_run_service.kyc_kyb_service.status[0].url
}

output "connector_service_url" {
  description = "Connector service URL"
  value       = google_cloud_run_service.connector_service.status[0].url
}

output "orchestration_service_url" {
  description = "Orchestration service URL"
  value       = google_cloud_run_service.orchestration_service.status[0].url
}

output "vpc_connector" {
  description = "VPC connector name"
  value       = google_vpc_access_connector.cloud_run_connector.name
}

output "load_balancer_ip" {
  description = "The IP address of the Load Balancer"
  value       = try(google_compute_global_address.proxy_ip.address, "")
}

output "load_balancer_url" {
  description = "The URL of the Load Balancer"
  value       = try(var.proxy_domain != "" ? "https://${var.proxy_domain}" : "http://${google_compute_global_address.proxy_ip.address}", "")
}

