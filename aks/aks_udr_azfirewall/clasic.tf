# --- Define Variable used
variable "resource_group_name" {
  type    = string
  default = "aksvnet"
}

variable "virtual_network" {
  type        = string
  description = "The Virtual Network Name"
  default     = "aksvnet01"
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
#
# --- Azure Virtual Network
resource "azurerm_virtual_network" "aksvnet" {
  name                = var.virtual_network
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  address_space       = ["10.0.0.0/16"]

  subnet {
    name = "AzureFirewallSubnet"
    address_prefix = "10.0.2.0/24"
  }

  subnet {
    name = "AzureFirewallManagementSubnet"
    address_prefix = "10.0.3.0/24"
  }

}

resource "azurerm_subnet" "default" {
  name                 = var.aks_subnet_name
  resource_group_name  = azurerm_resource_group.resource_group.name
  virtual_network_name = azurerm_virtual_network.aksvnet.name
  address_prefixes     = ["10.0.1.0/24"]
}


resource "azurerm_route_table" "aks_default_rt" {
  name                          = var.aks_subnet_rt
  location                      = azurerm_resource_group.resource_group.location
  resource_group_name           = azurerm_resource_group.resource_group.name
  disable_bgp_route_propagation = false##

#  route {
#    name                   = "default"
#    address_prefix         = "0.0.0.0/0"
#    next_hop_type          = "VirtualAppliance"
#    next_hop_in_ip_address = azurerm_firewall.region1-fw01.ip_configuration[0].private_ip_address
#  }
}

resource "azurerm_subnet_route_table_association" "aks_subnet_association" {
  subnet_id      = azurerm_subnet.default.id
  route_table_id = azurerm_route_table.aks_default_rt.id
  depends_on = [azurerm_subnet.default]
}

# --- Azure Kubernetes Service Cluster

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aksvnet"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  dns_prefix          = "aksudertest-5dd"
  oidc_issuer_enabled       = true
  workload_identity_enabled = true
  default_node_pool {
    name           = "system"
    node_count     = 1
    vm_size        = "Standard_DS2_v2"
    vnet_subnet_id = azurerm_subnet.default.id
  }
  network_profile {
  network_plugin = "azure"
  service_cidr = "172.16.0.0/24"
  dns_service_ip = "172.16.0.10"
  }
  identity {
    type = "SystemAssigned"
  }
#  depends_on = [azurerm_firewall.region1-fw01]
}
