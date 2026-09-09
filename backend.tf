# -----------------------------------------------------------------------------
# backend.tf — remote Terraform state in Azure Storage
#
# State is NOT stored on a laptop. GitHub Actions and local runs share one
# state file in a blob container.
#
# Bootstrap once (creates RG + storage account + container):
#   .\scripts\bootstrap-state.ps1
#   # or: bash scripts/bootstrap-state.sh
#
# Then copy backend.hcl.example → backend.hcl and fill in the storage account
# name printed by the script. backend.hcl is gitignored.
#
#   terraform init -backend-config=backend.hcl
#
# In GitHub Actions the same values come from repository secrets / variables.
# -----------------------------------------------------------------------------

terraform {
  backend "azurerm" {
    # Configured via -backend-config=backend.hcl (local) or workflow env (CI).
  }
}
