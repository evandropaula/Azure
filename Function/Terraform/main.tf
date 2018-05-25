# ***** Input Variables *****

# Run "az account show" in the Azure Portal or local machine to gather this information
variable "subscription_id" {
  description = "Subscription id (GUID)"
}

variable "client_id" {
  description = "Service Principal Application Id (GUID)"
}

variable "client_secret" {
  description = "Service Principal Password/Key (String)"
}

# Run "az account show" to gather this information
variable "tenant_id" {
  description = "Tenant id (GUID)"
}

# ATTENTION:
#   1. Currently, changing a resource group location is not supported (e.g. West US -> East US)
#    Having that said, changing the location for an existent resource group will cause it to be DESTROYED
#    and RECREATED in the new location;
variable "location" {
  description = "Azure location where components will be provisioned."
}

variable "resource_group_name" {
  description = "Resource group name"
}

variable "tag_environment" {
  description = "Environment name (e.g. development, test, staging, production, etc.)"
}

variable "function_storage_account_name" {
  description = "Storage account name"
}

variable "function_hosting_plan_name" {
  description = "Azure Function hosting plan name"
}

variable "function_hosting_plan_tier" {
  description = "Azure Function hosting plan tier (e.g. Standard, Dynamic)"
}

variable "function_hosting_plan_size" {
  description = "Azure Function hosting plan size"
}

variable "function_application_name" {
  description = "Azure Function application name"
}

variable "data_storage_account_name" {
  description = "Storage account container name"
}

variable "data_storage_account_container_name" {
  description = "Storage account container name"
}

# ***** Service Principal Authentication *****
# The following information is required for authentication through Service Principal (Contributor role)
provider "azurerm" {
  subscription_id = "${var.subscription_id}"
  client_id       = "${var.client_id}"
  client_secret   = "${var.client_secret}"
  tenant_id       = "${var.tenant_id}"
}

# ***** Resource Group *****
resource "azurerm_resource_group" "rg" {
  name     = "${var.resource_group_name}"
  location = "${var.location}"

  tags {
    Environment = "${var.tag_environment}"
    Location    = "${var.location}"
  }
}

# ***** Data Storage Account *****
resource "azurerm_storage_account" "data_storage_account" {
  name                     = "${var.data_storage_account_name}"
  resource_group_name      = "${azurerm_resource_group.rg.name}"
  location                 = "${azurerm_resource_group.rg.location}"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags {
    Environment = "${var.tag_environment}"
    Location    = "${var.location}"
  }
}

resource "azurerm_storage_container" "data_storage_account_container" {
  name                  = "${var.data_storage_account_container_name}"
  resource_group_name   = "${azurerm_resource_group.rg.name}"
  storage_account_name  = "${azurerm_storage_account.data_storage_account.name}"
  container_access_type = "private"
}

# ***** Function Storage Account *****
resource "azurerm_storage_account" "function_storage_account" {
  name                     = "${var.function_storage_account_name}"
  resource_group_name      = "${azurerm_resource_group.rg.name}"
  location                 = "${azurerm_resource_group.rg.location}"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags {
    Environment = "${var.tag_environment}"
    Location    = "${var.location}"
  }
}

# ***** Function Hosting Plan *****
resource "azurerm_app_service_plan" "hosting_plan" {
  name                = "${var.function_hosting_plan_name}"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"

  sku {
    tier = "${var.function_hosting_plan_tier}"
    size = "${var.function_hosting_plan_size}"
  }

  tags {
    Environment = "${var.tag_environment}"
    Location    = "${var.location}"
  }
}

# ***** Function Application *****
resource "azurerm_function_app" "function_application" {
  name                      = "${var.function_application_name}"
  location                  = "${azurerm_resource_group.rg.location}"
  resource_group_name       = "${azurerm_resource_group.rg.name}"
  app_service_plan_id       = "${azurerm_app_service_plan.hosting_plan.id}"
  storage_connection_string = "${azurerm_storage_account.function_storage_account.primary_connection_string}"
  version                   = "beta"

  app_settings {
    ContainerName = "${azurerm_storage_container.data_storage_account_container.name}"
  }

  connection_string {
    name  = "StorageAccountConnectionString"
    type  = "Custom"
    value = "${azurerm_storage_account.data_storage_account.primary_connection_string}"
  }

  tags {
    Environment = "${var.tag_environment}"
    Location    = "${var.location}"
  }
}
