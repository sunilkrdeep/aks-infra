# -----------------------------------------------------------------------------
# providers.tf — how Terraform authenticates to Azure
#
# Local laptop:  az login   (interactive — nothing secret is committed)
# GitHub Actions: OIDC via env ARM_USE_OIDC=true (see .github/workflows).
#                 Never set ARM_CLIENT_SECRET. Never commit client secrets.
#
# azurerm 4.x requires subscription_id explicitly (it no longer infers it).
# -----------------------------------------------------------------------------

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
