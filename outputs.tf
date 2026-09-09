# -----------------------------------------------------------------------------
# outputs.tf — values printed after terraform apply
#
# Use them as a cheat-sheet: copy/paste into PowerShell to talk to the cluster.
# Sensitive outputs (kube_config) are hidden in the CLI unless you run:
#   terraform output -raw kube_config
# -----------------------------------------------------------------------------

output "resource_group_name" {
  description = "Azure resource group that owns the cluster"
  value       = azurerm_resource_group.aks.name
}

output "cluster_name" {
  description = "AKS cluster name"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "cluster_fqdn" {
  description = "Public FQDN of the Kubernetes API server (the managed control plane)"
  value       = azurerm_kubernetes_cluster.aks.fqdn
}

output "kubernetes_version" {
  description = "Kubernetes version running on the control plane"
  value       = azurerm_kubernetes_cluster.aks.kubernetes_version
}

output "node_resource_group" {
  description = "Azure-managed RG that holds the 2 worker VMs, NICs, disks, and load balancer (do not edit by hand)"
  value       = azurerm_kubernetes_cluster.aks.node_resource_group
}

output "get_credentials_command" {
  description = "Merge AKS credentials into your local kubeconfig"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.aks.name} --name ${azurerm_kubernetes_cluster.aks.name} --overwrite-existing"
}

output "verify_nodes_command" {
  description = "List the 2 worker nodes after credentials are downloaded"
  value       = "kubectl get nodes -o wide"
}

output "kube_config" {
  description = "Raw kubeconfig (sensitive). Prefer az aks get-credentials instead."
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive   = true
}

output "acr_name" {
  description = "Azure Container Registry name (set as ACR_NAME on the sample-app GitHub repo)"
  value       = azurerm_container_registry.acr.name
}

output "acr_login_server" {
  description = "ACR login server host (e.g. myregistry.azurecr.io)"
  value       = azurerm_container_registry.acr.login_server
}

output "sample_app_image_prefix" {
  description = "Image prefix for sample-app CI (append :tag)"
  value       = "${azurerm_container_registry.acr.login_server}/sample-app"
}
