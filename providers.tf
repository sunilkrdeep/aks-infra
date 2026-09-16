# -----------------------------------------------------------------------------
# AzureRM provider
#
# Authentication is supplied by the execution environment:
#
# Local development:
#   az login
#
# GitHub Actions:
#   Azure OIDC via ARM_* environment variables
#
# No client secret is stored in Terraform configuration.
# -----------------------------------------------------------------------------

provider "azurerm" {
  features {}
}
