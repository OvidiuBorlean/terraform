variable "resource_group_name" {
  type = string
  default = "aksudr"
}

variable "virtual_network" {
  type = string
  description = "The Virtual Network Name"
  default = "aksvnet"
}

variable "location" {
  type = string
  default = "West Europe"
}
