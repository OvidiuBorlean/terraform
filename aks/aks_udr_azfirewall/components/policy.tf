resource "azurerm_firewall_policy" "azfw_policy" {
  name                     = "azfw-policy"
  resource_group_name      = azurerm_resource_group.resource_group.name
  location                 = azurerm_resource_group.resource_group.location
  sku                      = "Basic"
  threat_intelligence_mode = "Alert"
}


resource "azurerm_firewall_policy_rule_collection_group" "prcg" {
  name               = "prcg"
  firewall_policy_id = azurerm_firewall_policy.azfw_policy.id
  priority           = 300
  network_rule_collection {
    name     = "netRc1"
    priority = 200
    action   = "Allow"
    rule {
      name                  = "allowall"
      protocols             = ["TCP"]
      source_addresses      = ["*"]
      destination_addresses = ["*"]
      destination_ports     = ["*"]
    }
  }
}
