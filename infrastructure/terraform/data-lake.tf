# Data Lake - Raw Storage (Hot)
resource "google_storage_bucket" "data_lake_raw" {
  name          = "${var.project_id}-data-lake-raw"
  location      = var.region
  force_destroy = false

  uniform_bucket_level_access = true

  lifecycle_rule {
    condition {
      age = 90  # Move to nearline after 90 days
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  lifecycle_rule {
    condition {
      age = 365  # Move to coldline after 1 year
    }
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }

  lifecycle_rule {
    condition {
      age = 2555  # Delete after 7 years (GDPR compliance)
    }
    action {
      type = "Delete"
    }
  }

  versioning {
    enabled = true
  }

  labels = {
    environment = var.environment
    purpose     = "data-lake-raw"
  }
}

# Data Lake - Archive Storage (Cold)
resource "google_storage_bucket" "data_lake_archive" {
  name          = "${var.project_id}-data-lake-archive"
  location      = var.region
  force_destroy = false
  storage_class = "COLDLINE"

  uniform_bucket_level_access = true

  lifecycle_rule {
    condition {
      age = 2555  # Delete after 7 years
    }
    action {
      type = "Delete"
    }
  }

  labels = {
    environment = var.environment
    purpose     = "data-lake-archive"
  }
}

# Regional buckets for GDPR compliance
resource "google_storage_bucket" "data_lake_regional" {
  for_each = toset([
    "uk",
    "au",
    "nz",
    "uae",
    "us",
    "eu"
  ])

  name          = "${var.project_id}-data-lake-${each.key}"
  location      = var.region
  force_destroy = false

  uniform_bucket_level_access = true

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  lifecycle_rule {
    condition {
      age = 365
    }
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }

  lifecycle_rule {
    condition {
      age = 2555
    }
    action {
      type = "Delete"
    }
  }

  versioning {
    enabled = true
  }

  labels = {
    environment = var.environment
    purpose     = "data-lake-regional"
    region      = each.key
  }
}

# IAM bindings for service accounts to access data lake
resource "google_storage_bucket_iam_member" "data_lake_raw_access" {
  for_each = {
    for svc in google_service_account.services : svc.account_id => svc
  }

  bucket = google_storage_bucket.data_lake_raw.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${each.value.email}"
}

resource "google_storage_bucket_iam_member" "data_lake_archive_access" {
  for_each = {
    for svc in google_service_account.services : svc.account_id => svc
  }

  bucket = google_storage_bucket.data_lake_archive.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${each.value.email}"
}

# BigQuery dataset for analytics
resource "google_bigquery_dataset" "credovo_analytics" {
  dataset_id  = "credovo_analytics"
  location    = var.region
  description = "Credovo analytics data warehouse"

  labels = {
    environment = var.environment
  }

  access {
    role          = "OWNER"
    user_by_email = google_service_account.services["kyc-kyb-service"].email
  }
}


