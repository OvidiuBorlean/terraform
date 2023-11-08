resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aksudr-test"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  dns_prefix          = "aksudertest-5dd"

  default_node_pool {
    name           = "system"
    node_count     = 1
    vm_size        = "Standard_DS2_v2"
    vnet_subnet_id = azurerm_subnet.aksdefault.id
  }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
    outbound_type     = "userDefinedRouting"
    service_cidr      = "10.0.255.0/24"
    dns_service_ip            = "10.0.255.10"
  }

  identity {
    type = "SystemAssigned"
  }
  depends_on = [azurerm_firewall.region1-fw01]
}
