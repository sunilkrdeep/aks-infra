
# -----------------------------------------------------------------------------
# variables.tf — all configurable Terraform inputs
#
# Values can be supplied through environment-specific terraform.tfvars files
# or through the Terraform CLI.
#
# Azure authentication values such as subscription_id are supplied by the
# GitHub Actions CI/CD environment and should NOT be stored in terraform.tfvars.
# -----------------------------------------------------------------------------

variable "enable_cluster" {
  description = "Set to true to deploy the AKS cluster, or false to destroy the cluster while keeping supporting resources (e.g. VNet, ACR)."
  type        = bool
  default     = true
}

variable "subscription_id" {
  description = "Azure subscription ID supplied by the CI/CD environment."
  type        = string

  validation {
    condition = can(regex(
      "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$",
      var.subscription_id
    ))

    error_message = "subscription_id must be a valid Azure subscription GUID."
  }
}

variable "location" {
  description = "Azure region. Example: eastus, centralindia, westeurope."
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Name of the Azure resource group that holds the VNet and AKS cluster."
  type        = string
  default     = "rg-aks-lab"
}

variable "cluster_name" {
  description = "AKS cluster name. Also used as a prefix for related resources."
  type        = string
  default     = "aks-lab"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,24}$", var.cluster_name))
    error_message = "cluster_name must be 3-24 lowercase letters, numbers, or hyphens."
  }
}

variable "kubernetes_version" {
  description = "Kubernetes version for the AKS control plane. Empty string = Azure's current default."
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Worker nodes
# -----------------------------------------------------------------------------

variable "node_count" {
  description = "Number of worker-node VMs in the system node pool."
  type        = number
  default     = 2

  validation {
    condition     = var.node_count >= 1 && var.node_count <= 10
    error_message = "node_count must be between 1 and 10 for this lab."
  }
}

variable "node_vm_size" {
  description = "Azure VM size for each worker node."
  type        = string
  default     = "Standard_D2s_v3"
}

variable "os_disk_size_gb" {
  description = "OS disk size in GiB on each worker VM."
  type        = number
  default     = 64
}

variable "node_os_sku" {
  description = "Linux distribution used by AKS worker nodes."
  type        = string
  default     = "AzureLinux"
}

# -----------------------------------------------------------------------------
# Networking
# -----------------------------------------------------------------------------

variable "vnet_address_space" {
  description = "CIDR for the virtual network that hosts AKS nodes."
  type        = string
  default     = "10.10.0.0/16"
}

variable "aks_subnet_prefix" {
  description = "CIDR for the subnet where AKS worker nodes run."
  type        = string
  default     = "10.10.1.0/24"
}

# -----------------------------------------------------------------------------
# Azure Container Registry
# -----------------------------------------------------------------------------

variable "acr_name" {
  description = "Azure Container Registry name. Alphanumeric only. Empty = auto-generated."
  type        = string
  default     = ""

  validation {
    condition     = var.acr_name == "" || can(regex("^[a-zA-Z0-9]{5,50}$", var.acr_name))
    error_message = "acr_name must be empty or 5-50 alphanumeric characters (no hyphens)."
  }
}

variable "acr_sku" {
  description = "Azure Container Registry SKU."
  type        = string
  default     = "Basic"
}

# -----------------------------------------------------------------------------
# Tags
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Tags applied to every Azure resource Terraform creates."
  type        = map(string)

  default = {
    project     = "aks-lab"
    managed_by  = "terraform"
    environment = "dev"
    owner       = "sunil"
  }
}
