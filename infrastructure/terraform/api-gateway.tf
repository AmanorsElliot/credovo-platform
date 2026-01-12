# API Gateway for Proxy Service
# This provides public access to the proxy service without Load Balancer authentication issues

# Enable API Gateway API
resource "google_project_service" "api_gateway_api" {
  project = var.project_id
  service = "apigateway.googleapis.com"

  disable_dependent_services = false
  disable_on_destroy         = false
  
  depends_on = [time_sleep.wait_for_apis]
}

# API Gateway API Config
resource "google_api_gateway_api" "proxy_api" {
  provider     = google
  api_id       = "proxy-api"
  display_name = "Proxy Service API"
  project      = var.project_id
  
  depends_on = [google_project_service.api_gateway_api]
}

# API Gateway API Config (OpenAPI spec)
resource "google_api_gateway_api_config" "proxy_api_config" {
  provider      = google
  api           = google_api_gateway_api.proxy_api.api_id
  api_config_id = "proxy-api-config"
  project       = var.project_id

  openapi_documents {
    document {
      path     = "openapi.yaml"
      contents = base64encode(templatefile("${path.module}/api-gateway-openapi.yaml", {
        orchestration_service_url = "https://orchestration-service-saz24fo3sa-ew.a.run.app"
      }))
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [google_api_gateway_api.proxy_api]
}

# API Gateway Gateway
resource "google_api_gateway_gateway" "proxy_gateway" {
  provider   = google
  api_config = google_api_gateway_api_config.proxy_api_config.id
  gateway_id = "proxy-gateway"
  project    = var.project_id
  region     = var.region

  depends_on = [google_api_gateway_api_config.proxy_api_config]
}

# Output the API Gateway URL
output "api_gateway_url" {
  description = "The URL of the API Gateway"
  value       = "https://${google_api_gateway_gateway.proxy_gateway.default_hostname}"
}
