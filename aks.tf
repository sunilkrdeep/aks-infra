# -----------------------------------------------------------------------------
# aks.tf — Azure Kubernetes Service cluster
#
# WHAT YOU GET
#   Control plane / master  → Azure-managed (API server, etcd, scheduler,
#                             controller-manager). You never see these VMs.
#                             On the Free SKU you do not pay for them.
#
#   Worker nodes            → 2 Azure VMs (var.node_count) in the default
#                             system node pool. These run your pods. You pay
#                             for the VMs, disks, and a Standard Load Balancer.
#
# WHY YOU CANNOT CREATE A MASTER VM
#   AKS is a *managed* Kubernetes service. Azure owns the control plane.
#   If you need a self-managed master VM you would build kubeadm / k3s on
#   raw VMs instead — that is not AKS.
# -----------------------------------------------------------------------------
import {
  to = azurerm_kubernetes_cluster.aks[0]
  id = "/subscriptions/3a5237f2-fd9c-490b-a303-8bd660d58441/resourceGroups/aks-sutramind-rg/providers/Microsoft.ContainerService/managedClusters/aks-sutramind"
}
resource "azurerm_kubernetes_cluster" "aks" {
  count               = var.enable_cluster ? 1 : 0
  name                = var.cluster_name
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  dns_prefix          = local.dns_prefix
  kubernetes_version  = local.kubernetes_version

  # Free = no SLA, no charge for control plane (good for learning).
  # Paid  = "Standard" SKU with an SLA on the API server.
  sku_tier = "Free"

  # -----------------------------------------------------------------------
  # Default (system) node pool = your 2 worker VMs
  # -----------------------------------------------------------------------
  default_node_pool {
    name            = "system"
    node_count      = var.node_count
    vm_size         = var.node_vm_size
    os_disk_size_gb = var.os_disk_size_gb
    os_sku          = var.node_os_sku
    vnet_subnet_id  = azurerm_subnet.aks.id

    # System pools run kube-system pods (CoreDNS, metrics, …) plus your apps.
    # Do not set only "User" here — AKS requires at least one system pool.
    type = "VirtualMachineScaleSets"

    upgrade_settings {
      max_surge = "10%"
    }
  }

  # Cluster identity: AKS uses this to create related Azure objects
  # (load balancers, public IPs, disks) on your behalf.
  identity {
    type = "SystemAssigned"
  }

  # Azure CNI Overlay: worker VMs get IPs from snet-aks; pods get IPs
  # from pod_cidr so the subnet is not exhausted (1 IP per pod).
  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    pod_cidr            = "10.244.0.0/16"
    load_balancer_sku   = "standard"
    outbound_type       = "loadBalancer"
  }

  # Lets you run: az aks get-credentials … then kubectl
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  tags = local.common_tags
}

# The cluster identity needs permission to attach NICs in the AKS subnet
# (required when you bring your own VNet).
resource "azurerm_role_assignment" "aks_network" {
  count                = var.enable_cluster ? 1 : 0
  scope                = azurerm_virtual_network.aks.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks[0].identity[0].principal_id
}
