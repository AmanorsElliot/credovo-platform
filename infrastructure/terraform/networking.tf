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

  expiration_policy {
    ttl = "300000.5s"
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
    automatic = true
  }

  labels = {
    environment = var.environment
    purpose     = "auth"
  }
}

resource "google_secret_manager_secret" "lovable_audience" {
  secret_id = "lovable-audience"

  replication {
    automatic = true
  }

  labels = {
    environment = var.environment
    purpose     = "auth"
  }
}

resource "google_secret_manager_secret" "service_jwt_secret" {
  secret_id = "service-jwt-secret"

  replication {
    automatic = true
  }

  labels = {
    environment = var.environment
    purpose     = "auth"
  }
}

# Example: Secret for SumSub API key
resource "google_secret_manager_secret" "sumsub_api_key" {
  secret_id = "sumsub-api-key"

  replication {
    automatic = true
  }

  labels = {
    environment = var.environment
    provider     = "sumsub"
  }
}

# Example: Secret for Companies House API key
resource "google_secret_manager_secret" "companies_house_api_key" {
  secret_id = "companies-house-api-key"

  replication {
    automatic = true
  }

  labels = {
    environment = var.environment
    provider     = "companies-house"
  }
}

