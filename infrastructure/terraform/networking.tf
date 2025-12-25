# Pub/Sub topics for event-driven architecture
resource "google_pubsub_topic" "kyc_events" {
  name = "kyc-events"
  
  labels = {
    environment = var.environment
    service     = "kyc-kyb-service"
  }
}

resource "google_pubsub_topic" "application_events" {
  name = "application-events"
  
  labels = {
    environment = var.environment
  }
}

# Pub/Sub subscriptions
resource "google_pubsub_subscription" "kyc_events_subscription" {
  name  = "kyc-events-subscription"
  topic = google_pubsub_topic.kyc_events.name

  ack_deadline_seconds = 20
  
  # Message retention duration must be <= expiration policy TTL
  message_retention_duration = "604800s"  # 7 days

  expiration_policy {
    ttl = "604800s"  # 7 days - must be >= message_retention_duration
  }

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }
}

# Cloud Tasks queues
resource "google_cloud_tasks_queue" "kyc_queue" {
  name     = "kyc-queue"
  location = var.region
  
  depends_on = [google_project_service.required_apis]

  rate_limits {
    max_concurrent_dispatches = 10
    max_dispatches_per_second = 5
  }

  retry_config {
    max_attempts       = 3
    max_retry_duration = "3600s"
    min_backoff        = "5s"
    max_backoff        = "300s"
    max_doublings      = 5
  }
}

# Secret Manager secrets (placeholders - actual secrets should be created manually or via separate process)
resource "google_secret_manager_secret" "lovable_jwks_uri" {
  secret_id = "lovable-jwks-uri"

  replication {
    auto {}
  }

  labels = {
    environment = var.environment
    purpose     = "auth"
  }
  
  depends_on = [time_sleep.wait_for_apis]
}

resource "google_secret_manager_secret" "lovable_audience" {
  secret_id = "lovable-audience"

  replication {
    auto {}
  }

  labels = {
    environment = var.environment
    purpose     = "auth"
  }
  
  depends_on = [time_sleep.wait_for_apis]
}

resource "google_secret_manager_secret" "service_jwt_secret" {
  secret_id = "service-jwt-secret"

  replication {
    auto {}
  }

  labels = {
    environment = var.environment
    purpose     = "auth"
  }
  
  depends_on = [time_sleep.wait_for_apis]
}

# Example: Secret for SumSub API key
resource "google_secret_manager_secret" "sumsub_api_key" {
  secret_id = "sumsub-api-key"

  replication {
    auto {}
  }

  labels = {
    environment = var.environment
    provider     = "sumsub"
  }
  
  depends_on = [time_sleep.wait_for_apis]
}

# Example: Secret for Companies House API key
resource "google_secret_manager_secret" "companies_house_api_key" {
  secret_id = "companies-house-api-key"

  replication {
    auto {}
  }

  labels = {
    environment = var.environment
    provider     = "companies-house"
  }
  
  depends_on = [time_sleep.wait_for_apis]
}

# Create initial placeholder secret versions so Cloud Run can reference them
# These will be updated with actual values later via the configure-secrets script
resource "google_secret_manager_secret_version" "lovable_jwks_uri_version" {
  secret      = google_secret_manager_secret.lovable_jwks_uri.id
  secret_data = "https://auth.lovable.dev/.well-known/jwks.json"  # Placeholder - will be updated
  
  depends_on = [google_secret_manager_secret.lovable_jwks_uri]
}

resource "google_secret_manager_secret_version" "lovable_audience_version" {
  secret      = google_secret_manager_secret.lovable_audience.id
  secret_data = "credovo-api"  # Placeholder - will be updated
  
  depends_on = [google_secret_manager_secret.lovable_audience]
}

resource "google_secret_manager_secret_version" "service_jwt_secret_version" {
  secret      = google_secret_manager_secret.service_jwt_secret.id
  secret_data = base64encode("placeholder-jwt-secret-change-me")  # Placeholder - will be updated
  
  depends_on = [google_secret_manager_secret.service_jwt_secret]
}

resource "google_secret_manager_secret_version" "sumsub_api_key_version" {
  secret      = google_secret_manager_secret.sumsub_api_key.id
  secret_data = "placeholder-sumsub-key"  # Placeholder - will be updated
  
  depends_on = [google_secret_manager_secret.sumsub_api_key]
}

resource "google_secret_manager_secret_version" "companies_house_api_key_version" {
  secret      = google_secret_manager_secret.companies_house_api_key.id
  secret_data = "placeholder-companies-house-key"  # Placeholder - will be updated
  
  depends_on = [google_secret_manager_secret.companies_house_api_key]
}

# Wait for secret versions to be fully available
resource "time_sleep" "wait_for_secret_versions" {
  depends_on = [
    google_secret_manager_secret_version.lovable_jwks_uri_version,
    google_secret_manager_secret_version.lovable_audience_version,
    google_secret_manager_secret_version.service_jwt_secret_version
  ]
  
  create_duration = "30s"  # Wait 30 seconds for secret versions to be available
}

