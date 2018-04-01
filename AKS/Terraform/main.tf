# ***** Input Variables *****

# Run "az account show" to gather this information
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
#   2. As of (03/30/2018) AKS is only available in: eastus, westeurope, centralus, canadacentral and canadaeast;
variable "location" {
  description = "Azure location where components will be provisioned."
}

variable "resource_group_name" {
  description = "Resource group name"
}

variable "aks_cluster_name" {
  description = "AKS cluster name"
}

variable "aks_cluster_k8s_version" {
  description = "AKS cluster k8s version (e.g. 1.8.7)"
}

variable "aks_cluster_dns_prefix" {
  description = "AKS cluster DNS prefix"
}

variable "aks_cluster_admin_user_name" {
  description = "AKS cluster admin user name"
}

variable "aks_cluster_ssh_key" {
  description = "AKS cluster SSH key"
}

variable aks_cluster_vm_count {
  description = "AKS cluster VM count"
}

variable "aks_cluster_vm_sku" {
  description = "AKS cluster VM SKU (e.g. Standard_D2_v2)"
}

variable "tag_environment" {
  description = "Environment name"
}

# ATTENTION: 
variable "aks_cluster_client_id" {
  description = "AKS cluster Service Principal application id (GUID)"
}

variable "aks_cluster_client_secret" {
  description = "AKS cluster Service Principal key"
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

# ***** AKS Cluster *****
resource "azurerm_kubernetes_cluster" "test" {
  name                = "${var.aks_cluster_name}"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  kubernetes_version  = "${var.aks_cluster_k8s_version}"
  dns_prefix          = "${var.aks_cluster_dns_prefix}"

  linux_profile {
    admin_username = "${var.aks_cluster_admin_user_name}"

    ssh_key {
      key_data = "${var.aks_cluster_ssh_key}"
    }
  }

  agent_pool_profile {
    name            = "default"
    count           = "${var.aks_cluster_vm_count}"
    vm_size         = "${var.aks_cluster_vm_sku}"
    os_type         = "Linux"
    os_disk_size_gb = 30
  }

  # ATTENTION:
  #   1. Consider using a separate Service Principal account for the AKS cluster;
  #   2. Create the Service Principal account WITHOUT ANY role assignments,
  #     the Contributor role will be assigned to it during provisioning and
  #     it will scoped to the resource group MC_{resource group name}_{AKS cluster name}_{region name};
  #   3. Integrating with Azure Container Registry that IS NOT in the resource group MC_*
  #     requires the Service Principal to have access (prefarebly read-only) to the ACR and/or its resource group
  service_principal {
    client_id     = "${var.aks_cluster_client_id}"
    client_secret = "${var.aks_cluster_client_secret}"
  }

  tags {
    Environment = "${var.tag_environment}"
    Location    = "${var.location}"
  }
}
