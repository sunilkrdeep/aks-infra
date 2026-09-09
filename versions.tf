# -----------------------------------------------------------------------------
# versions.tf — Terraform CLI + provider versions
#
# This block is processed first. Terraform will refuse to run if:
#   - your terraform CLI is older than required_version
#   - a provider cannot be downloaded at the requested version
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    # Talks to Azure Resource Manager (resource groups, VNets, AKS, VMs, …)
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }

    # Creates a short random suffix so the AKS DNS name is globally unique
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
