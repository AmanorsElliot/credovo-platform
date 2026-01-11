# Configure Clearbit API Key in GCP Secret Manager
# This script helps you securely store your Clearbit API key from HubSpot

param(
    [Parameter(Mandatory=$false)]
    [string]$ProjectId = "credovo-eu-apps-nonprod",
    
    [Parameter(Mandatory=$false)]
    [string]$Region = "europe-west1"
)

Write-Host "=== Clearbit API Key Configuration ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "This script will help you store your Clearbit API key in GCP Secret Manager."
Write-Host "You need to get your API key from the Clearbit dashboard first."
Write-Host ""
Write-Host "To get your Clearbit API key:"
Write-Host "1. Go to https://clearbit.com/ and log in (or access via HubSpot)"
Write-Host "2. Navigate to Settings > API Keys"
Write-Host "3. Create a new API key or copy an existing one"
Write-Host ""
Write-Host "See docs/CLEARBIT_HUBSPOT_SETUP.md for detailed instructions."
Write-Host ""

# Prompt for API key
$apiKey = Read-Host "Enter your Clearbit API key" -AsSecureString
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($apiKey)
$plainApiKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

if ([string]::IsNullOrWhiteSpace($plainApiKey)) {
    Write-Host "Error: API key cannot be empty" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Storing Clearbit API key in Secret Manager..." -ForegroundColor Yellow

# Check if secret exists
$secretExists = gcloud secrets describe clearbit-api-key --project=$ProjectId 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "Secret 'clearbit-api-key' already exists. Adding new version..." -ForegroundColor Yellow
    echo $plainApiKey | gcloud secrets versions add clearbit-api-key `
        --data-file=- `
        --project=$ProjectId
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Successfully added new version to existing secret" -ForegroundColor Green
    } else {
        Write-Host "✗ Failed to add secret version" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Creating new secret 'clearbit-api-key'..." -ForegroundColor Yellow
    echo $plainApiKey | gcloud secrets create clearbit-api-key `
        --data-file=- `
        --project=$ProjectId `
        --replication-policy="user-managed" `
        --locations=$Region
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Successfully created secret" -ForegroundColor Green
    } else {
        Write-Host "✗ Failed to create secret" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "=== Next Steps ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Update the connector service to use the Clearbit API key:"
Write-Host "   gcloud run services update connector-service \"
Write-Host "     --update-secrets=CLEARBIT_API_KEY=clearbit-api-key:latest \"
Write-Host "     --region=$Region \"
Write-Host "     --project=$ProjectId"
Write-Host ""
Write-Host "2. Configure company-search-service to use Clearbit:"
Write-Host "   gcloud run services update company-search-service \"
Write-Host "     --update-env-vars=COMPANY_SEARCH_PROVIDER=clearbit \"
Write-Host "     --region=$Region \"
Write-Host "     --project=$ProjectId"
Write-Host ""
Write-Host "3. Or uncomment the Clearbit env section in infrastructure/terraform/cloud-run.tf"
Write-Host "   and run: terraform apply"
Write-Host ""
Write-Host "See docs/CLEARBIT_HUBSPOT_SETUP.md for more details." -ForegroundColor Green
