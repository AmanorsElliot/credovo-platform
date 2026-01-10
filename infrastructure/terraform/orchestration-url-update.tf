# Update ORCHESTRATION_SERVICE_URL after services are created
# This avoids the circular dependency between orchestration_service and kyc_kyb_service

resource "null_resource" "update_orchestration_url" {
  # This runs after both services are created
  depends_on = [
    google_cloud_run_service.orchestration_service,
    google_cloud_run_service.kyc_kyb_service
  ]

  triggers = {
    orchestration_url = google_cloud_run_service.orchestration_service.status[0].url
    kyc_kyb_service   = google_cloud_run_service.kyc_kyb_service.id
  }

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = "gcloud run services update kyc-kyb-service --region=${var.region} --update-env-vars=\"ORCHESTRATION_SERVICE_URL=${google_cloud_run_service.orchestration_service.status[0].url}\" --project=${var.project_id} --quiet"
  }
}
}

