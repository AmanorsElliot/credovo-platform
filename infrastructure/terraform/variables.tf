variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "europe-west1"
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "europe-west1-b"
}

variable "environment" {
  description = "Environment (staging, production)"
  type        = string
  default     = "staging"
}

variable "min_instances" {
  description = "Minimum Cloud Run instances"
  type        = number
  default     = 0
}

variable "max_instances" {
  description = "Maximum Cloud Run instances"
  type        = number
  default     = 10
}

variable "notification_channels" {
  description = "List of notification channel IDs for alerts (optional - will use email channel if not provided)"
  type        = list(string)
  default     = []
}

variable "alert_email_address" {
  description = "Email address for alert notifications"
  type        = string
  default     = ""
}

variable "domain" {
  description = "Domain name for Grafana (e.g., credovo.com)"
  type        = string
  default     = ""
}

variable "grafana_admin_user" {
  description = "Grafana admin username"
  type        = string
  default     = "admin"
}

variable "github_repo" {
  description = "GitHub repository in format owner/repo"
  type        = string
  default     = "AmanorsElliot/credovo-platform"
}

