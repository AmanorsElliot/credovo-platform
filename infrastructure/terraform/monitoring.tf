# Cloud Monitoring alert policies

# Alert for high error rate (5xx errors)
resource "google_monitoring_alert_policy" "high_error_rate" {
  display_name = "High Error Rate - Cloud Run"
  combiner     = "OR"
  conditions {
    display_name = "Error rate threshold (5xx)"
    condition_threshold {
      filter          = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/request_count\" AND metric.label.response_code_class=\"5xx\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 5  # Alert if more than 5 errors in 5 minutes
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
        group_by_fields    = ["resource.label.service_name"]
      }
    }
  }

  notification_channels = length(var.notification_channels) > 0 ? var.notification_channels : (var.alert_email_address != "" ? [google_monitoring_notification_channel.email.id] : [])

  alert_strategy {
    auto_close = "1800s"
  }
}

# Alert for high latency
resource "google_monitoring_alert_policy" "high_latency" {
  display_name = "High Latency - Cloud Run"
  combiner     = "OR"
  conditions {
    display_name = "Latency threshold"
    condition_threshold {
      filter          = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/request_latencies\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 5000  # 5 seconds
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_DELTA"
        cross_series_reducer = "REDUCE_PERCENTILE_95"
        group_by_fields      = ["resource.label.service_name"]
      }
    }
  }

  notification_channels = length(var.notification_channels) > 0 ? var.notification_channels : (var.alert_email_address != "" ? [google_monitoring_notification_channel.email.id] : [])

  alert_strategy {
    auto_close = "1800s"
  }
}

# Alert for service unavailability
resource "google_monitoring_alert_policy" "service_unavailable" {
  display_name = "Service Unavailable - Cloud Run"
  combiner     = "OR"
  conditions {
    display_name = "Service down"
    condition_threshold {
      filter          = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/container/instance_count\""
      duration        = "60s"
      comparison      = "COMPARISON_LT"
      threshold_value = 1
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
        group_by_fields    = ["resource.label.service_name"]
      }
    }
  }

  notification_channels = length(var.notification_channels) > 0 ? var.notification_channels : (var.alert_email_address != "" ? [google_monitoring_notification_channel.email.id] : [])

  alert_strategy {
    auto_close = "1800s"
  }
}

# Dashboard for Cloud Run services
resource "google_monitoring_dashboard" "cloud_run_dashboard" {
  dashboard_json = jsonencode({
    displayName = "Credovo Cloud Run Services"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          xPos   = 0
          yPos   = 0
          width  = 6
          height = 4
          widget = {
            title = "Request Count"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/request_count\""
                  }
                }
              }]
            }
          }
        },
        {
          xPos   = 6
          yPos   = 0
          width  = 6
          height = 4
          widget = {
            title = "Request Latency (p95)"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/request_latencies\""
                  }
                }
              }]
            }
          }
        },
        {
          xPos   = 0
          yPos   = 4
          width  = 6
          height = 4
          widget = {
            title = "Error Rate"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/request_count\" AND metric.label.response_code_class=\"5xx\""
                  }
                }
              }]
            }
          }
        },
        {
          xPos   = 6
          yPos   = 4
          width  = 6
          height = 4
          widget = {
            title = "Instance Count"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/container/instance_count\""
                  }
                }
              }]
            }
          }
        }
      ]
    }
  })
}

# Log-based metrics for custom tracking
resource "google_logging_metric" "kyc_initiated" {
  name   = "kyc_initiated"
  filter = "resource.type=\"cloud_run_revision\" AND jsonPayload.applicationId!=\"\" AND jsonPayload.event=\"kyc_initiated\""
  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
  }
}

resource "google_logging_metric" "kyc_completed" {
  name   = "kyc_completed"
  filter = "resource.type=\"cloud_run_revision\" AND jsonPayload.applicationId!=\"\" AND jsonPayload.event=\"kyc_completed\""
  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
  }
}

# Webhook-specific metrics
resource "google_logging_metric" "webhook_received" {
  name   = "webhook_received"
  filter = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"orchestration-service\" AND textPayload=~\"webhook\" AND textPayload=~\"Received Shufti Pro webhook\""
  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
  }
}

resource "google_logging_metric" "webhook_failed" {
  name   = "webhook_failed"
  filter = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"orchestration-service\" AND textPayload=~\"webhook\" AND (severity=\"ERROR\" OR severity=\"WARNING\")"
  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
  }
}

resource "google_logging_metric" "kyb_initiated" {
  name   = "kyb_initiated"
  filter = "resource.type=\"cloud_run_revision\" AND jsonPayload.applicationId!=\"\" AND jsonPayload.event=\"kyb_initiated\""
  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
  }
}

resource "google_logging_metric" "kyb_completed" {
  name   = "kyb_completed"
  filter = "resource.type=\"cloud_run_revision\" AND jsonPayload.applicationId!=\"\" AND jsonPayload.event=\"kyb_completed\""
  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
  }
}

resource "google_logging_metric" "aml_screening" {
  name   = "aml_screening"
  filter = "resource.type=\"cloud_run_revision\" AND (jsonPayload.aml!=\"\" OR jsonPayload.risk_assessment!=\"\")"
  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
  }
}

# Alert for webhook failures
# Note: Uses log-based metric which may take up to 10 minutes to become available
# Add depends_on to ensure metric exists, or apply in two steps
resource "google_monitoring_alert_policy" "webhook_failures" {
  display_name = "Webhook Processing Failures"
  combiner     = "OR"
  conditions {
    display_name = "Webhook failure rate"
    condition_threshold {
      filter          = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"orchestration-service\" AND metric.type=\"logging.googleapis.com/user/webhook_failed\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 3  # Alert if more than 3 webhook failures in 5 minutes
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = length(var.notification_channels) > 0 ? var.notification_channels : (var.alert_email_address != "" ? [google_monitoring_notification_channel.email.id] : [])

  alert_strategy {
    auto_close = "1800s"
  }

  # Wait for log-based metric to be available (may take up to 10 minutes)
  depends_on = [
    google_logging_metric.webhook_failed,
    time_sleep.wait_for_metrics
  ]
}

# Wait for log-based metrics to propagate
resource "time_sleep" "wait_for_metrics" {
  depends_on = [
    google_logging_metric.webhook_received,
    google_logging_metric.webhook_failed,
    google_logging_metric.kyc_initiated,
    google_logging_metric.kyc_completed,
    google_logging_metric.kyb_initiated,
    google_logging_metric.kyb_completed,
    google_logging_metric.aml_screening
  ]

  create_duration = "600s"  # Wait 10 minutes for metrics to propagate
}

# Alert for missing webhooks (if no webhooks received in expected time)
resource "google_monitoring_alert_policy" "missing_webhooks" {
  display_name = "Missing Webhooks - No Activity"
  combiner     = "OR"
  conditions {
    display_name = "No webhook activity"
    condition_absent {
      filter          = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"orchestration-service\" AND metric.type=\"logging.googleapis.com/user/webhook_received\""
      duration        = "1800s"  # 30 minutes
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = length(var.notification_channels) > 0 ? var.notification_channels : (var.alert_email_address != "" ? [google_monitoring_notification_channel.email.id] : [])

  alert_strategy {
    auto_close = "3600s"
  }
  
  # Only enable this alert if we expect regular webhook activity
  enabled = false  # Set to true if you want to monitor for missing webhooks
}

# Alert for high KYC/KYB failure rate
resource "google_monitoring_alert_policy" "kyc_kyb_failures" {
  display_name = "High KYC/KYB Failure Rate"
  combiner     = "OR"
  conditions {
    display_name = "KYC/KYB failure rate"
    condition_threshold {
      filter          = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"kyc-kyb-service\" AND metric.type=\"run.googleapis.com/request_count\" AND metric.label.response_code_class=\"5xx\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 3  # Alert if more than 3 failures in 5 minutes
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = length(var.notification_channels) > 0 ? var.notification_channels : (var.alert_email_address != "" ? [google_monitoring_notification_channel.email.id] : [])

  alert_strategy {
    auto_close = "1800s"
  }
}

# Alert for data lake storage failures
resource "google_monitoring_alert_policy" "data_lake_storage_failures" {
  display_name = "Data Lake Storage Failures"
  combiner     = "OR"
  conditions {
    display_name = "Storage write failures"
    condition_threshold {
      filter          = "resource.type=\"cloud_run_revision\" AND textPayload=~\"Failed to store.*data lake\" AND severity=\"ERROR\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 2  # Alert if more than 2 storage failures in 5 minutes
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
        group_by_fields    = ["resource.label.service_name"]
      }
    }
  }

  notification_channels = length(var.notification_channels) > 0 ? var.notification_channels : (var.alert_email_address != "" ? [google_monitoring_notification_channel.email.id] : [])

  alert_strategy {
    auto_close = "1800s"
  }
}

# Alert for connector service failures
resource "google_monitoring_alert_policy" "connector_service_failures" {
  display_name = "Connector Service Failures"
  combiner     = "OR"
  conditions {
    display_name = "Connector service errors"
    condition_threshold {
      filter          = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"connector-service\" AND metric.type=\"run.googleapis.com/request_count\" AND metric.label.response_code_class=\"5xx\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 3  # Alert if more than 3 errors in 5 minutes
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = length(var.notification_channels) > 0 ? var.notification_channels : (var.alert_email_address != "" ? [google_monitoring_notification_channel.email.id] : [])

  alert_strategy {
    auto_close = "1800s"
  }
}

