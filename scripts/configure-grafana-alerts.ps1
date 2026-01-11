# Configure Grafana alerts for new and completed applications
# This script uses Grafana API to set up alert rules

param(
    [string]$GrafanaUrl = "",
    [string]$GrafanaApiKey = "",
    [string]$DashboardUid = "credovo-multi-region",
    [string]$NotificationChannelName = ""
)

$ErrorActionPreference = "Stop"

Write-Host "=== Configure Grafana Alerts ===" -ForegroundColor Cyan
Write-Host ""

if ([string]::IsNullOrEmpty($GrafanaUrl)) {
    $GrafanaUrl = Read-Host "Enter Grafana URL (e.g., https://grafana.example.com)"
}

if ([string]::IsNullOrEmpty($GrafanaApiKey)) {
    Write-Host "Grafana API Key required. Create one at: $GrafanaUrl/org/apikeys" -ForegroundColor Yellow
    $GrafanaApiKey = Read-Host "Enter Grafana API Key" -AsSecureString
    $GrafanaApiKey = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($GrafanaApiKey)
    )
}

$headers = @{
    "Authorization" = "Bearer $GrafanaApiKey"
    "Content-Type" = "application/json"
}

# Get dashboard
Write-Host "Fetching dashboard..." -ForegroundColor Yellow
try {
    $dashboardResponse = Invoke-RestMethod -Uri "$GrafanaUrl/api/dashboards/uid/$DashboardUid" -Headers $headers -Method Get
    $dashboard = $dashboardResponse.dashboard
    Write-Host "  [OK] Dashboard found" -ForegroundColor Green
} catch {
    Write-Host "  [FAIL] Failed to fetch dashboard: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Create notification channel if provided
$notificationChannelId = $null
if (-not [string]::IsNullOrEmpty($NotificationChannelName)) {
    Write-Host "Creating notification channel..." -ForegroundColor Yellow
    
    $channelConfig = @{
        name = $NotificationChannelName
        type = "email"
        settings = @{
            addresses = Read-Host "Enter email address for alerts"
        }
        isDefault = $true
    } | ConvertTo-Json -Depth 10
    
    try {
        $channelResponse = Invoke-RestMethod -Uri "$GrafanaUrl/api/alert-notifications" -Headers $headers -Method Post -Body $channelConfig
        $notificationChannelId = $channelResponse.id
        Write-Host "  [OK] Notification channel created (ID: $notificationChannelId)" -ForegroundColor Green
    } catch {
        Write-Host "  [WARN] Failed to create notification channel: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "  You can create it manually in Grafana UI" -ForegroundColor Gray
    }
}

# Update dashboard panels with alerts
Write-Host ""
Write-Host "Configuring alerts on dashboard panels..." -ForegroundColor Yellow

$panelsUpdated = 0
foreach ($panel in $dashboard.panels) {
    if ($panel.title -match "KYC.*Initiated|KYB.*Initiated|KYC.*Completed|KYB.*Completed") {
        if (-not $panel.alert) {
            $panel.alert = @{
                conditions = @(
                    @{
                        evaluator = @{
                            params = @(0)
                            type = "gt"
                        }
                        operator = @{
                            type = "and"
                        }
                        query = @{
                            params = @("A", "1m", "now")
                        }
                        reducer = @{
                            params = @()
                            type = "sum"
                        }
                        type = "query"
                    }
                )
                executionErrorState = "alerting"
                for = "0s"
                frequency = "30s"
                handler = 1
                name = if ($panel.title -match "Initiated") { "New $($panel.title)" } else { "$($panel.title) Completed" }
                noDataState = "no_data"
                notifications = if ($notificationChannelId) { @($notificationChannelId) } else { @() }
            }
            $panelsUpdated++
            Write-Host "  [OK] Added alert to: $($panel.title)" -ForegroundColor Green
        }
    }
}

if ($panelsUpdated -gt 0) {
    # Update dashboard
    $dashboardUpdate = @{
        dashboard = $dashboard
        overwrite = $true
    } | ConvertTo-Json -Depth 20
    
    try {
        Invoke-RestMethod -Uri "$GrafanaUrl/api/dashboards/db" -Headers $headers -Method Post -Body $dashboardUpdate | Out-Null
        Write-Host ""
        Write-Host "  [OK] Dashboard updated with $panelsUpdated alert(s)" -ForegroundColor Green
    } catch {
        Write-Host ""
        Write-Host "  [FAIL] Failed to update dashboard: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "  [INFO] No panels needed updating" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Alert Configuration Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Alerts configured for:" -ForegroundColor White
Write-Host "  - New KYC Applications" -ForegroundColor Gray
Write-Host "  - New KYB Applications" -ForegroundColor Gray
Write-Host "  - Completed KYC Applications" -ForegroundColor Gray
Write-Host "  - Completed KYB Applications" -ForegroundColor Gray
Write-Host ""
Write-Host "View alerts at: $GrafanaUrl/alerting/list" -ForegroundColor White
Write-Host ""
