# create a data resource and get the management group
data "azurerm_management_group" "sandbox" {
  name = var.sandbox-mg-id
}

data "azurerm_management_group" "decomissioned" {
  name = var.decomissioned-mg-id
}

# create resource group
resource "azurerm_resource_group" "resource_group" {
  name     = "${var.resource-prefix}-rg"
  location = var.location
}