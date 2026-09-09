# -----------------------------------------------------------------------------
# locals.tf — derived values used in more than one file
#
# Locals are like constants computed from variables. They are NOT inputs.
# Change variables.tf / terraform.tfvars; keep this file as glue.
# -----------------------------------------------------------------------------

locals {
  # dns_prefix must be unique in the Azure region (it becomes part of the API FQDN).
  dns_prefix = "${var.cluster_name}-${random_string.suffix.result}"

  # ACR names: 5–50 alphanumeric only (no hyphens). Globally unique.
  acr_name = var.acr_name != "" ? var.acr_name : "acr${replace(var.cluster_name, "-", "")}${random_string.suffix.result}"

  # If kubernetes_version is "", omit it and let Azure pick the default.
  kubernetes_version = var.kubernetes_version != "" ? var.kubernetes_version : null

  common_tags = var.tags
}

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
  numeric = true
}
