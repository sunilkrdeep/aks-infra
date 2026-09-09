# Copy this file to terraform.tfvars and fill in your subscription:
#   copy terraform.tfvars.example terraform.tfvars
#
# Find your subscription ID:
#   az login
#   az account show --query id -o tsv

subscription_id     = "3a5237f2-fd9c-490b-a303-8bd660d58441"
location            = "southindia"
resource_group_name = "aks-sutramind-rg"
cluster_name        = "aks-sutramind"

# Set to false to destroy the AKS cluster via code; set to true to recreate it
enable_cluster = false

# Leave empty to use Azure's default Kubernetes version
kubernetes_version = ""

# 1 worker-node VM (lab). Control plane is Azure-managed (not a VM you create).
node_count      = 1
node_vm_size    = "Standard_B2s_v2"
os_disk_size_gb = 30

# Tags applied to every Azure resource Terraform creates
tags = {
  project     = "aks-sutramind"
  managed_by  = "terraform"
  environment = "dev"
  owner       = "Sunil"
}