resource "azurerm_public_ip" "region1-fw01-pip" {
  name                = "region1-fw01-pip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags = {
    Environment    = "Production"
  }
  depends_on = [azurerm_resource_group.resource_group] 
}
#Azure Firewall Instance
resource "azurerm_firewall" "region1-fw01" {
  name                = "region1-fw01"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_tier = "Basic"
  sku_name = "AZFW_VNet"
  #management_ip_configuration = azurerm_public_ip.management-fw01-pip.name
  ip_configuration {
    name                 = "fw-ipconfig"
    subnet_id            = azurerm_subnet.azurefirewall.id
    public_ip_address_id = azurerm_public_ip.region1-fw01-pip.id
 }
  management_ip_configuration {
    name = "azfw_management_ip"
    subnet_id = azurerm_subnet.azurefirewallmanagement.id
    public_ip_address_id = azurerm_public_ip.management-fw01-pip.id
 }
 firewall_policy_id = azurerm_firewall_policy.azfw_policy.id
}

#azurerm_public_ip" "management-fw01-pip"
