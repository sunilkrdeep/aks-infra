# -----------------------------------------------------------------------------
# network.tf — Azure resource group + VNet + subnet for AKS worker nodes
#
# Diagram:
#
#   Resource Group (rg-aks-lab)
#     └── Virtual Network  10.10.0.0/16
#           └── Subnet "aks"  10.10.1.0/24   ← the 2 worker VMs land here
#
# The AKS *control plane* does NOT live in this VNet. Microsoft hosts it in
# an Azure-managed subscription. Nodes talk to the API server over a
# private-link / tunnel that AKS sets up for you.
# -----------------------------------------------------------------------------
import {
  to = azurerm_resource_group.aks
  id = "/subscriptions/3a5237f2-fd9c-490b-a303-8bd660d58441/resourceGroups/aks-sutramind-rg"
}

import {
  to = azurerm_virtual_network.aks
  id = "/subscriptions/3a5237f2-fd9c-490b-a303-8bd660d58441/resourceGroups/aks-sutramind-rg/providers/Microsoft.Network/virtualNetworks/aks-sutramind-vnet"
}

import {
  to = azurerm_subnet.aks
  id = "/subscriptions/3a5237f2-fd9c-490b-a303-8bd660d58441/resourceGroups/aks-sutramind-rg/providers/Microsoft.Network/virtualNetworks/aks-sutramind-vnet/subnets/snet-aks"
}

resource "azurerm_resource_group" "aks" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_virtual_network" "aks" {
  name                = "${var.cluster_name}-vnet"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  address_space       = [var.vnet_address_space]
  tags                = local.common_tags
}

resource "azurerm_subnet" "aks" {
  name                 = "snet-aks"
  resource_group_name  = azurerm_resource_group.aks.name
  virtual_network_name = azurerm_virtual_network.aks.name
  address_prefixes     = [var.aks_subnet_prefix]
}
