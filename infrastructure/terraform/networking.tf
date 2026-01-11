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
    user_managed {
      replicas {
        location = var.region
      }
    }
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
    user_managed {
      replicas {
        location = var.region
      }
    }
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
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  labels = {
    environment = var.environment
    purpose     = "auth"
  }
  
  depends_on = [time_sleep.wait_for_apis]
}

resource "google_secret_manager_secret" "supabase_url" {
  secret_id = "supabase-url"

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  labels = {
    environment = var.environment
    purpose     = "auth"
    provider    = "supabase"
  }
  
  depends_on = [time_sleep.wait_for_apis]
}

# Example: Secret for SumSub API key
resource "google_secret_manager_secret" "sumsub_api_key" {
  secret_id = "sumsub-api-key"

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
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
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  labels = {
    environment = var.environment
    provider     = "companies-house"
  }
  
  depends_on = [time_sleep.wait_for_apis]
}

# Shufti Pro credentials (primary KYC/KYB provider)
resource "google_secret_manager_secret" "shufti_pro_client_id" {
  secret_id = "shufti-pro-client-id"

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  labels = {
    environment = var.environment
    provider    = "shufti-pro"
    purpose      = "kyc-kyb"
  }
  
  depends_on = [time_sleep.wait_for_apis]
}

resource "google_secret_manager_secret" "shufti_pro_secret_key" {
  secret_id = "shufti-pro-secret-key"

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  labels = {
    environment = var.environment
    provider    = "shufti-pro"
    purpose      = "kyc-kyb"
  }
  
  depends_on = [time_sleep.wait_for_apis]
}

# Plaid credentials (open banking provider)
resource "google_secret_manager_secret" "plaid_client_id" {
  secret_id = "plaid-client-id"

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  labels = {
    environment = var.environment
    provider    = "plaid"
    purpose      = "open-banking"
  }
  
  depends_on = [time_sleep.wait_for_apis]
}

resource "google_secret_manager_secret" "plaid_secret_key" {
  secret_id = "plaid-secret-key"

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  labels = {
    environment = var.environment
    provider    = "plaid"
    purpose      = "open-banking"
  }
  
  depends_on = [time_sleep.wait_for_apis]
}

resource "google_secret_manager_secret" "plaid_secret_key_prod" {
  secret_id = "plaid-secret-key-prod"

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  labels = {
    environment = "production"
    provider    = "plaid"
    purpose      = "open-banking"
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

resource "google_secret_manager_secret_version" "supabase_url_version" {
  secret      = google_secret_manager_secret.supabase_url.id
  secret_data = "https://your-project.supabase.co"  # Placeholder - will be updated with actual Supabase project URL
  
  depends_on = [google_secret_manager_secret.supabase_url]
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

# Shufti Pro secret versions with actual credentials
# Using sandbox credentials for dev/nonprod environment
resource "google_secret_manager_secret_version" "shufti_pro_client_id_version" {
  secret      = google_secret_manager_secret.shufti_pro_client_id.id
  secret_data = "c29799b84a29a8cc335af9fdbcf150e198a8babc3175c42d699751763bbce442"
  
  depends_on = [google_secret_manager_secret.shufti_pro_client_id]
}

resource "google_secret_manager_secret_version" "shufti_pro_secret_key_version" {
  secret      = google_secret_manager_secret.shufti_pro_secret_key.id
  secret_data = "fQC91wjAO5OweifiRohmyqEFvKVN6wzh"
  
  depends_on = [google_secret_manager_secret.shufti_pro_secret_key]
}

# Plaid secret versions (using sandbox for nonprod)
resource "google_secret_manager_secret_version" "plaid_client_id_version" {
  secret      = google_secret_manager_secret.plaid_client_id.id
  secret_data = "695f4eebbd1561001d2a5159"  # Plaid Client ID
  
  depends_on = [google_secret_manager_secret.plaid_client_id]
}

resource "google_secret_manager_secret_version" "plaid_secret_key_version" {
  secret      = google_secret_manager_secret.plaid_secret_key.id
  secret_data = "2bf99d20b80c1cebf3b98da518f220"  # Plaid Sandbox Secret
  
  depends_on = [google_secret_manager_secret.plaid_secret_key]
}

resource "google_secret_manager_secret_version" "plaid_secret_key_prod_version" {
  secret      = google_secret_manager_secret.plaid_secret_key_prod.id
  secret_data = "4fa53299017068600116eb956c80de"  # Plaid Production Secret
  
  depends_on = [google_secret_manager_secret.plaid_secret_key_prod]
}

# Wait for secret versions to be fully available
resource "time_sleep" "wait_for_secret_versions" {
  depends_on = [
    google_secret_manager_secret_version.lovable_jwks_uri_version,
    google_secret_manager_secret_version.lovable_audience_version,
    google_secret_manager_secret_version.service_jwt_secret_version,
    google_secret_manager_secret_version.plaid_client_id_version,
    google_secret_manager_secret_version.plaid_secret_key_version
  ]
  
  create_duration = "30s"  # Wait 30 seconds for secret versions to be available
}

