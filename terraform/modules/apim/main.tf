variable "location" {
  description = "Location for APIM"
  type        = string
}

variable "apim_name" {
  description = "API Management service name"
  type        = string
}

variable "publisher_name" {
  description = "Publisher name"
  type        = string
}

variable "publisher_email" {
  description = "Publisher email"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "foundry_east_us_2_url" {
  description = "Backend URL for East US 2 foundry"
  type        = string
  sensitive   = true
}

variable "foundry_west_us_3_url" {
  description = "Backend URL for West US 3 foundry"
  type        = string
  sensitive   = true
}

resource "azurerm_api_management" "apim" {
  name                = var.apim_name
  location            = var.location
  resource_group_name = var.resource_group_name
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email
  sku_name            = "Developer_1"

  identity {
    type = "SystemAssigned"
  }
}

# Backend for the first foundry (East US 2)
resource "azurerm_api_management_backend" "east_us_2" {
  name                = "foundry-batch-sticky-east-us-2"
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.apim.name
  protocol            = "http"
  url                 = var.foundry_east_us_2_url
  title               = "Foundry Backend - East US 2"
  description         = "Backend for AI Foundry in East US 2 (v1 API)"
}

# Backend for the second foundry (West US 3)
resource "azurerm_api_management_backend" "west_us_3" {
  name                = "foundry-batch-sticky-west-us-3"
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.apim.name
  protocol            = "http"
  url                 = var.foundry_west_us_3_url
  title               = "Foundry Backend - West US 3"
  description         = "Backend for AI Foundry in West US 3 (v1 API)"
}

# Backend pool with random load balancing
# Using azapi provider since azurerm doesn't support pool configuration
resource "azapi_resource" "pool" {
  type      = "Microsoft.ApiManagement/service/backends@2023-05-01-preview"
  name      = "foundry-pool"
  parent_id = azurerm_api_management.apim.id

  body = {
    properties = {
      description = "Load balanced pool of foundry backends"
      type        = "Pool"
      pool = {
        services = [
          {
            id = azurerm_api_management_backend.east_us_2.id
          },
          {
            id = azurerm_api_management_backend.west_us_3.id
          }
        ]
      }
    }
  }

  depends_on = [
    azurerm_api_management_backend.east_us_2,
    azurerm_api_management_backend.west_us_3
  ]
}

output "apim_name" {
  value = azurerm_api_management.apim.name
}

output "apim_id" {
  value = azurerm_api_management.apim.id
}

output "apim_gateway_url" {
  value = azurerm_api_management.apim.gateway_url
}

output "apim_principal_id" {
  value = azurerm_api_management.apim.identity[0].principal_id
}

output "backend_east_us_2_id" {
  value = azurerm_api_management_backend.east_us_2.id
}

output "backend_west_us_3_id" {
  value = azurerm_api_management_backend.west_us_3.id
}

output "backend_pool_id" {
  value = azapi_resource.pool.id
}
