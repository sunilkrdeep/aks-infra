location            = "centralindia"
resource_group_name = "Sutramind-ci01-rg"
cluster_name        = "sutramind-ci01-aks"

# Set  to false to destroy the AKS cluster via code; set to true to recreate it
enable_cluster = true

# Leave empty to use Azure's default Kubernetes version
kubernetes_version = ""

# 1 worker-node VM (lab). Control plane is Azure-managed (not a VM you create).
node_count      = 2
node_vm_size    = "Standard_B2s_v2"
os_disk_size_gb = 30

# Tags applied to every Azure resource Terraform creates
tags = {
  project     = "sutramind-ci01-aks"
  managed_by  = "terraform"
  environment = "dev"
  owner       = "Sunil"
}
