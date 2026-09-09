# -----------------------------------------------------------------------------
# acr.tf — Azure Container Registry + AcrPull for AKS nodes
#
# sample-app CI builds images and pushes here. AKS kubelet pulls with AcrPull
# (no docker credentials in the cluster).
# -----------------------------------------------------------------------------

resource "azurerm_container_registry" "acr" {
  name                = local.acr_name
  resource_group_name = azurerm_resource_group.aks.name
  location            = azurerm_resource_group.aks.location
  sku                 = var.acr_sku
  admin_enabled       = false
  tags                = local.common_tags
}

# Allow AKS nodes (kubelet identity) to pull images from this registry.
resource "azurerm_role_assignment" "aks_acr_pull" {
  count                = var.enable_cluster ? 1 : 0
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks[0].kubelet_identity[0].object_id
}
