# -----------------------------------------------------------------------------
# providers.tf — how Terraform authenticates to Azure
#
# Authentication (pick one; az login is the easiest for learning):
#   1. Azure CLI:  az login   then   az account set --subscription <id>
#   2. Env vars:   ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_TENANT_ID, ARM_SUBSCRIPTION_ID
#   3. Managed identity (when Terraform itself runs on an Azure VM / pipeline)
#
# azurerm 4.x requires subscription_id explicitly (it no longer infers it).
# -----------------------------------------------------------------------------

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
