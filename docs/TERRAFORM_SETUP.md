# Terraform Setup for Windows

## Option 1: Install via Chocolatey (Recommended)

If you have Chocolatey installed:
```powershell
choco install terraform
```

## Option 2: Manual Installation

1. Download Terraform from: https://developer.hashicorp.com/terraform/downloads
2. Choose Windows 64-bit version
3. Extract the zip file
4. Add Terraform to your PATH:
   - Copy `terraform.exe` to a folder (e.g., `C:\terraform`)
   - Add `C:\terraform` to your System PATH environment variable
   - Restart PowerShell/terminal

## Option 3: Install via Winget

```powershell
winget install HashiCorp.Terraform
```

## Verify Installation

```powershell
terraform --version
```

Should show: `Terraform v1.5.0` or higher

## After Installation

Once Terraform is installed, continue with:

```powershell
cd C:\Users\ellio\Documents\credovo-platform\infrastructure\terraform

# Initialize Terraform
terraform init

# Review what will be created
terraform plan

# Deploy infrastructure
terraform apply
```

