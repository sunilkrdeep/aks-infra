#Requires -Version 5.1
<#
.SYNOPSIS
  One-time bootstrap: Azure Storage for Terraform remote state.

.DESCRIPTION
  Creates resource group, storage account (globally unique name), and blob
  container. Writes backend.hcl next to this script's parent folder.

  Run once before: terraform init -backend-config=backend.hcl
#>

param(
  [string]$Location = "southindia",
  [string]$ResourceGroupName = "rg-tfstate",
  [string]$ContainerName = "tfstate",
  [string]$StateKey = "aks-infra.tfstate"
)

$ErrorActionPreference = "Stop"

$az = Get-Command az -ErrorAction SilentlyContinue
if (-not $az) {
  throw "Azure CLI (az) not found. Install: https://learn.microsoft.com/cli/azure/install-azure-cli"
}

Write-Host "Using subscription:" -ForegroundColor Cyan
az account show --query "{name:name, id:id}" -o table

$suffix = -join ((48..57) + (97..122) | Get-Random -Count 8 | ForEach-Object { [char]$_ })
$storageAccountName = "sttfstate$suffix"

Write-Host "Creating resource group $ResourceGroupName in $Location ..." -ForegroundColor Cyan
az group create --name $ResourceGroupName --location $Location --output none

Write-Host "Creating storage account $storageAccountName ..." -ForegroundColor Cyan
az storage account create `
  --name $storageAccountName `
  --resource-group $ResourceGroupName `
  --location $Location `
  --sku Standard_LRS `
  --kind StorageV2 `
  --allow-blob-public-access false `
  --min-tls-version TLS1_2 `
  --output none

Write-Host "Creating container $ContainerName ..." -ForegroundColor Cyan
az storage container create `
  --name $ContainerName `
  --account-name $storageAccountName `
  --auth-mode login `
  --output none

$root = Split-Path $PSScriptRoot -Parent
$backendPath = Join-Path $root "backend.hcl"
@"
resource_group_name  = "$ResourceGroupName"
storage_account_name = "$storageAccountName"
container_name       = "$ContainerName"
key                  = "$StateKey"
use_azuread_auth     = true
"@ | Set-Content -Path $backendPath -Encoding utf8

Write-Host ""
Write-Host "Wrote $backendPath" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. terraform init -backend-config=backend.hcl"
Write-Host "  2. Add these as GitHub Variables on aks-infra:"
Write-Host "       TF_STATE_RESOURCE_GROUP = $ResourceGroupName"
Write-Host "       TF_STATE_STORAGE_ACCOUNT = $storageAccountName"
Write-Host "       TF_STATE_CONTAINER = $ContainerName"
Write-Host "       TF_STATE_KEY = $StateKey"
