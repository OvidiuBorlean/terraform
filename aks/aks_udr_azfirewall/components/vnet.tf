resource "azurerm_resource_group" "resource_group" {
  name     = var.resource_group_name
  location = "West Europe"
}

resource "azurerm_public_ip" "management-fw01-pip" {
  name                = "management-fw01-pip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags = {
    Environment    = "Production"
  }
  depends_on = [azurerm_resource_group.resource_group]
}

#resource "azurerm_network_security_group" "example" {
#  name                = "example-security-group"
#  location            = azurerm_resource_group.resource_group.location
#  resource_group_name = azurerm_resource_group.resource_group.name
#}

resource "azurerm_virtual_network" "aksvnet" {
  name                = var.virtual_network
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "aksdefault" {
  name                 = "aksdefault"
  resource_group_name  = azurerm_resource_group.resource_group.name
  virtual_network_name = azurerm_virtual_network.aksvnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "azurefirewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.resource_group.name
  virtual_network_name = azurerm_virtual_network.aksvnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_subnet" "azurefirewallmanagement" {
  name                 = "AzureFirewallManagementSubnet"
  resource_group_name  = azurerm_resource_group.resource_group.name
  virtual_network_name = azurerm_virtual_network.aksvnet.name
  address_prefixes     = ["10.0.3.0/24"]
}

resource "azurerm_route_table" "aks_default_rt" {
  name                          = "aks-default"
  location                      = azurerm_resource_group.resource_group.location
  resource_group_name           = azurerm_resource_group.resource_group.name
  disable_bgp_route_propagation = false

  route {
    name                   = "default"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.region1-fw01.ip_configuration[0].private_ip_address
  }
}

resource "azurerm_subnet_route_table_association" "aks_subnet" {
  subnet_id      = azurerm_subnet.aksdefault.id
  route_table_id = azurerm_route_table.aks_default_rt.id
}
