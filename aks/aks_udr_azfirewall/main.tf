# --- Define Variable used
variable "resource_group_name" {
  type    = string
  default = "aksudr"
}

variable "virtual_network" {
  type        = string
  description = "The Virtual Network Name"
  default     = "aksvnet"
}

variable "location" {
  type    = string
  default = "West Europe"
}

variable "fw_public_ip_name" {
  type    = string
  default = "management-fw01-pip"
}

variable "aks_subnet_name" {
  type    = string
  default = "aksdefault"
}

variable "aks_subnet_rt" {
  type    = string
  default = "aks-default-rt"
}
# --- Terraform Main Block

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }

  }
}

# --- Azure Resource Group
resource "azurerm_resource_group" "resource_group" {
  name     = var.resource_group_name
  location = "West Europe"
}

# --- Network Security Group - Optional
#resource "azurerm_network_security_group" "example" {
#  name                = "example-security-group"
#  location            = azurerm_resource_group.resource_group.location
#  resource_group_name = azurerm_resource_group.resource_group.name
#}

# --- Azure Virtual Network
resource "azurerm_virtual_network" "aksvnet" {
  name                = var.virtual_network
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "aksdefault" {
  name                 = var.aks_subnet_name
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
  name                          = var.aks_subnet_rt
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

resource "azurerm_subnet_route_table_association" "aks_subnet_association" {
  subnet_id      = azurerm_subnet.aksdefault.id
  route_table_id = azurerm_route_table.aks_default_rt.id

}

# --- Azure Public IP Address for Azure Firewall Outbound connectivity and Management

resource "azurerm_public_ip" "region1-fw01-pip" {
  name                = "region1-fw01-pip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags = {
    Environment = "Production"
  }
  depends_on = [azurerm_resource_group.resource_group]
}

resource "azurerm_public_ip" "management-fw01-pip" {
  name                = var.fw_public_ip_name
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  depends_on          = [azurerm_resource_group.resource_group]
}

# --- Azure Firewall Instance
resource "azurerm_firewall" "region1-fw01" {
  name                = "region1-fw01"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_tier            = "Basic"
  sku_name            = "AZFW_VNet"
  #management_ip_configuration = azurerm_public_ip.management-fw01-pip.name
  ip_configuration {
    name                 = "fw-ipconfig"
    subnet_id            = azurerm_subnet.azurefirewall.id
    public_ip_address_id = azurerm_public_ip.region1-fw01-pip.id
  }
  management_ip_configuration {
    name                 = "azfw_management_ip"
    subnet_id            = azurerm_subnet.azurefirewallmanagement.id
    public_ip_address_id = azurerm_public_ip.management-fw01-pip.id
  }
  firewall_policy_id = azurerm_firewall_policy.azfw_policy.id
}

# --- Azure Firewall Policy

resource "azurerm_firewall_policy" "azfw_policy" {
  name                     = "azfw-policy"
  resource_group_name      = azurerm_resource_group.resource_group.name
  location                 = azurerm_resource_group.resource_group.location
  sku                      = "Basic"
  threat_intelligence_mode = "Alert"
}

# --- Auzre Policies

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

# --- Azure Kubernetes Service Cluster

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
    dns_service_ip    = "10.0.255.10"
  }

  identity {
    type = "SystemAssigned"
  }
  depends_on = [azurerm_firewall.region1-fw01]
}

