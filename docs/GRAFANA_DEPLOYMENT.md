# Grafana Deployment Guide - Complete Setup

This guide provides step-by-step instructions for deploying Grafana on GCP and configuring it for multi-region application monitoring.

## Prerequisites

- GCP project with billing enabled
- `gcloud` CLI installed and authenticated
- Terraform >= 1.5.0 installed
- PowerShell (for Windows) or Bash (for Linux/Mac)

## Quick Start

### 1. Run Setup Script

```powershell
# Windows PowerShell
.\scripts\setup-grafana.ps1 -ProjectId "credovo-eu-apps-nonprod" -Region "europe-west1"
```

```bash
# Linux/Mac (convert script or use gcloud commands directly)
# See manual setup below
```

The script will:
- ✅ Enable required GCP APIs
- ✅ Create service account with Monitoring Viewer permissions
- ✅ Grant permissions to all regional projects
- ✅ Deploy Grafana on Cloud Run
- ✅ Configure secrets in Secret Manager

### 2. Access Grafana

After deployment, you'll receive:
- **Grafana URL**: `https://grafana-XXXXX.run.app`
- **Admin Username**: `admin` (or custom)
- **Admin Password**: Stored in Secret Manager

Get the password:
```bash
gcloud secrets versions access latest --secret=grafana-admin-password --project=YOUR_PROJECT_ID
```

### 3. Configure Data Source

1. Log in to Grafana
2. Go to **Configuration → Data Sources**
3. Click **Add data source**
4. Select **Google Cloud Monitoring**
5. Configure:
   - **Name**: `Google Cloud Monitoring`
   - **Authentication**: JWT File
   - **Service Account Key**: Upload `grafana-service-account-key.json` (created by setup script)
6. Click **Save & Test**

### 4. Import Dashboard

1. Go to **Dashboards → Import**
2. Click **Upload JSON file**
3. Select `infrastructure/grafana/credovo-dashboard-enhanced.json`
4. Configure:
   - **Name**: Credovo Platform - Multi-Region Applications Dashboard
   - **Folder**: Credovo
   - **Data Source**: Select "Google Cloud Monitoring"
5. Click **Import**

### 5. Configure Project Variables

1. Edit the imported dashboard
2. Click the **Settings** icon (gear)
3. Go to **Variables**
4. Edit `project` variable:
   - Update query to include all projects:
     ```
     label_values(resource.label.project_id, resource.label.project_id)
     ```
   - Select all regional projects:
     - `credovo-uk-apps-prod`
     - `credovo-uae-apps-prod`
     - `credovo-us-apps-prod`
     - `credovo-eu-apps-prod`
5. Save dashboard

### 6. Set Up Alerts

#### Option A: Using Script (Recommended)

```powershell
.\scripts\configure-grafana-alerts.ps1 `
    -GrafanaUrl "https://grafana-XXXXX.run.app" `
    -GrafanaApiKey "YOUR_API_KEY" `
    -NotificationChannelName "Credovo Alerts"
```

Create API key:
1. Go to **Configuration → API Keys**
2. Click **New API Key**
3. Set name and role (Admin)
4. Copy the key

#### Option B: Manual Configuration

1. Edit dashboard
2. Select panel (e.g., "KYC Applications - Initiated vs Completed")
3. Click **Edit**
4. Go to **Alert** tab
5. Click **Create Alert**
6. Configure:
   - **Condition**: When `A` (sum) is greater than `0`
   - **Evaluate**: Every `30s` for `0s`
   - **Notifications**: Add notification channel
7. Save panel and dashboard

### 7. Configure Time Range Presets

The dashboard includes time range presets. To customize:

1. Edit dashboard
2. Click **Settings** icon
3. Go to **Time options**
4. Add custom presets:
   - **Daily**: `now/d` to `now`
   - **Weekly**: `now/w` to `now`
   - **Monthly**: `now/M` to `now`
5. Save dashboard

## Manual Setup (Alternative)

If the script doesn't work, follow these manual steps:

### 1. Enable APIs

```bash
gcloud services enable \
    run.googleapis.com \
    secretmanager.googleapis.com \
    monitoring.googleapis.com \
    cloudresourcemanager.googleapis.com \
    --project=YOUR_PROJECT_ID
```

### 2. Create Service Account

```bash
gcloud iam service-accounts create grafana-monitoring \
    --display-name="Grafana Monitoring Service Account" \
    --project=YOUR_PROJECT_ID
```

### 3. Grant Permissions

```bash
# For each regional project
for project in credovo-uk-apps-prod credovo-uae-apps-prod credovo-us-apps-prod credovo-eu-apps-prod; do
  gcloud projects add-iam-policy-binding $project \
    --member="serviceAccount:grafana-monitoring@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/monitoring.viewer"
done
```

### 4. Create Service Account Key

```bash
gcloud iam service-accounts keys create grafana-service-account-key.json \
    --iam-account=grafana-monitoring@YOUR_PROJECT_ID.iam.gserviceaccount.com \
    --project=YOUR_PROJECT_ID
```

### 5. Deploy with Terraform

```bash
cd infrastructure/terraform
terraform init
terraform apply \
    -var="project_id=YOUR_PROJECT_ID" \
    -var="region=europe-west1" \
    -var="grafana_admin_user=admin"
```

## Dashboard Features

### Time Range Presets

The dashboard includes:
- **Last 6 hours** (default)
- **Last 24 hours** (daily)
- **Last 7 days** (weekly)
- **Last 30 days** (monthly)
- Custom ranges

### Region-Specific Panels

- **UK Region**: KYC Completed panel
- **UAE Region**: KYC Completed panel
- **US Region**: KYC Completed panel
- **EU Region**: KYC Completed panel

### Alerts

Configured alerts:
- **New KYC Application**: Triggers when KYC is initiated
- **New KYB Application**: Triggers when KYB is initiated
- **KYC Application Completed**: Triggers when KYC is completed
- **KYB Application Completed**: Triggers when KYB is completed
- **High Latency**: Triggers when p95 latency > 5s

## Troubleshooting

### Grafana Not Accessible

1. Check Cloud Run service status:
   ```bash
   gcloud run services describe grafana --region=europe-west1
   ```

2. Check IAM permissions:
   ```bash
   gcloud run services get-iam-policy grafana --region=europe-west1
   ```

### No Data in Dashboard

1. **Check Data Source Connection**:
   - Test connection in data source settings
   - Verify service account key is correct

2. **Check Metric Availability**:
   - Ensure log-based metrics exist (see `monitoring.tf`)
   - Wait 10-15 minutes after metric creation

3. **Check Project Filter**:
   - Verify project variable includes correct projects
   - Check service account has access to all projects

### Alerts Not Working

1. **Check Alert Rules**:
   - Go to **Alerting → Alert Rules**
   - Verify rules are enabled

2. **Check Notification Channels**:
   - Go to **Alerting → Notification Channels**
   - Test channel

3. **Check Panel Alerts**:
   - Edit panel
   - Go to **Alert** tab
   - Verify condition is correct

## Security Best Practices

1. **Use IAP for Production**:
   - Replace `allUsers` with IAP in `grafana.tf`
   - Configure Identity-Aware Proxy

2. **Rotate Service Account Keys**:
   - Rotate keys every 90 days
   - Update in Grafana data source

3. **Limit Dashboard Access**:
   - Use Grafana teams/roles
   - Restrict to authorized users

4. **Secure Admin Password**:
   - Change default password
   - Store in Secret Manager (already done)

## Next Steps

- Set up additional dashboards for specific services
- Configure Slack/PagerDuty notifications
- Add custom metrics and panels
- Set up automated reports

## Support

For issues:
1. Check Grafana logs: `gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=grafana"`
2. Review Cloud Run service logs
3. Verify service account permissions
4. Check Terraform state
