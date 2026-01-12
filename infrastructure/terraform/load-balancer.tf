# HTTPS Load Balancer for Proxy Service
# This allows public access to the proxy service without requiring allUsers IAM binding
# The load balancer is publicly accessible, but the Cloud Run service remains private

variable "proxy_domain" {
  description = "Domain name for the proxy service (e.g., proxy.credovo.app). Leave empty to use IP only."
  type        = string
  default     = ""
}

# Enable required APIs for Load Balancer
resource "google_project_service" "load_balancer_apis" {
  for_each = toset([
    "compute.googleapis.com",
    "certificatemanager.googleapis.com"
  ])

  project = var.project_id
  service = each.value

  disable_dependent_services = false
  disable_on_destroy         = false
  
  depends_on = [time_sleep.wait_for_apis]
}

# Service account for Load Balancer to invoke Cloud Run
resource "google_service_account" "load_balancer" {
  account_id   = "load-balancer-proxy"
  display_name = "Load Balancer Service Account"
  description  = "Service account for Load Balancer to invoke Cloud Run services"
}

# Grant Load Balancer service account permission to invoke proxy service
# Note: The proxy-service must exist before applying this
resource "google_cloud_run_service_iam_member" "load_balancer_invoke_proxy" {
  service  = "proxy-service"
  location = var.region
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.load_balancer.email}"
}

# Managed SSL Certificate (Google-managed)
# Only create if domain is provided
resource "google_compute_managed_ssl_certificate" "proxy_ssl" {
  count = var.proxy_domain != "" ? 1 : 0
  
  name = "proxy-service-ssl-cert"

  managed {
    domains = [var.proxy_domain]
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [google_project_service.load_balancer_apis]
}

# Alternative: Self-signed certificate for testing (uncomment if needed)
# resource "tls_private_key" "proxy_key" {
#   algorithm = "RSA"
#   rsa_bits  = 2048
# }
#
# resource "tls_self_signed_cert" "proxy_cert" {
#   key_algorithm   = tls_private_key.proxy_key.algorithm
#   private_key_pem = tls_private_key.proxy_key.private_key_pem
#
#   subject {
#     common_name  = "proxy.credovo.app"
#     organization = "Credovo"
#   }
#
#   validity_period_hours = 8760  # 1 year
#
#   allowed_uses = [
#     "key_encipherment",
#     "digital_signature",
#     "server_auth",
#   ]
# }
#
# resource "google_compute_ssl_certificate" "proxy_ssl" {
#   name        = "proxy-service-ssl-cert"
#   private_key = tls_private_key.proxy_key.private_key_pem
#   certificate = tls_self_signed_cert.proxy_cert.cert_pem
# }

# Backend service pointing to Cloud Run
resource "google_compute_backend_service" "proxy_backend" {
  name                  = "proxy-service-backend"
  description           = "Backend service for proxy-service Cloud Run"
  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = 30
  enable_cdn            = false
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_region_network_endpoint_group.proxy_neg.id
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }

  depends_on = [google_compute_region_network_endpoint_group.proxy_neg]
}

# Network Endpoint Group (NEG) for Cloud Run
resource "google_compute_region_network_endpoint_group" "proxy_neg" {
  name                  = "proxy-service-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region
  cloud_run {
    service = "proxy-service"
  }
}

# URL Map
resource "google_compute_url_map" "proxy_url_map" {
  name            = "proxy-service-url-map"
  description     = "URL map for proxy service"
  default_service = google_compute_backend_service.proxy_backend.id

  dynamic "host_rule" {
    for_each = var.proxy_domain != "" ? [1] : []
    content {
      hosts        = [var.proxy_domain]
      path_matcher = "proxy-path-matcher"
    }
  }

  path_matcher {
    name            = "proxy-path-matcher"
    default_service = google_compute_backend_service.proxy_backend.id
  }
}

# Target HTTPS Proxy (only if SSL certificate exists)
resource "google_compute_target_https_proxy" "proxy_https" {
  count            = var.proxy_domain != "" ? 1 : 0
  name             = "proxy-service-https-proxy"
  url_map          = google_compute_url_map.proxy_url_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.proxy_ssl[0].id]
}

# Target HTTP Proxy (for testing without SSL)
resource "google_compute_target_http_proxy" "proxy_http" {
  count   = var.proxy_domain == "" ? 1 : 0
  name    = "proxy-service-http-proxy"
  url_map = google_compute_url_map.proxy_url_map.id
}

# Global Forwarding Rule (for HTTPS - if domain provided)
resource "google_compute_global_forwarding_rule" "proxy_https_forwarding" {
  count      = var.proxy_domain != "" ? 1 : 0
  name       = "proxy-service-https-forwarding"
  target     = google_compute_target_https_proxy.proxy_https[0].id
  port_range = "443"
  ip_protocol = "TCP"
  ip_address  = google_compute_global_address.proxy_ip.address
}

# Global Forwarding Rule (for HTTP - if no domain)
resource "google_compute_global_forwarding_rule" "proxy_http_forwarding" {
  count      = var.proxy_domain == "" ? 1 : 0
  name       = "proxy-service-http-forwarding"
  target     = google_compute_target_http_proxy.proxy_http[0].id
  port_range = "80"
  ip_protocol = "TCP"
  ip_address  = google_compute_global_address.proxy_ip.address
}

# Optional: Reserve a static IP address
resource "google_compute_global_address" "proxy_ip" {
  name         = "proxy-service-ip"
  address_type = "EXTERNAL"
  ip_version    = "IPV4"
}

# Output the Load Balancer IP
output "load_balancer_ip" {
  description = "The IP address of the Load Balancer"
  value       = google_compute_global_address.proxy_ip.address
}

# Output the Load Balancer URL
output "load_balancer_url" {
  description = "The URL of the Load Balancer"
  value       = var.proxy_domain != "" ? "https://${var.proxy_domain}" : "http://${google_compute_global_address.proxy_ip.address}"
}
