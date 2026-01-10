# Notification channels for alerting
# These will be created if they don't exist, or you can reference existing ones

# Email notification channel
# Note: Replace with your email address
resource "google_monitoring_notification_channel" "email" {
  display_name = "Credovo Alerts - Email"
  type         = "email"
  
  labels = {
    email_address = var.alert_email_address
  }

  enabled = true
}

# Optional: Slack notification channel
# Uncomment and configure if you want Slack notifications
# resource "google_monitoring_notification_channel" "slack" {
#   display_name = "Credovo Alerts - Slack"
#   type         = "slack"
#   
#   labels = {
#     channel_name = "#credovo-alerts"
#   }
#   
#   sensitive_labels {
#     auth_token = var.slack_webhook_url
#   }
#   
#   enabled = true
# }

# Optional: PagerDuty notification channel
# Uncomment and configure if you want PagerDuty integration
# resource "google_monitoring_notification_channel" "pagerduty" {
#   display_name = "Credovo Alerts - PagerDuty"
#   type         = "pagerduty"
#   
#   labels = {
#     service_key = var.pagerduty_service_key
#   }
#   
#   enabled = true
# }

