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

# Log Analytics workspace for APIM diagnostics
resource "azurerm_log_analytics_workspace" "apim" {
  name                = "log-${var.apim_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# Application Insights (workspace-based) for APIM
resource "azurerm_application_insights" "apim" {
  name                = "appi-${var.apim_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_id        = azurerm_log_analytics_workspace.apim.id
  application_type    = "web"
}

# APIM logger pointing to Application Insights
resource "azurerm_api_management_logger" "appinsights" {
  name                = "appinsights-logger"
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = var.resource_group_name
  resource_id         = azurerm_application_insights.apim.id

  application_insights {
    instrumentation_key = azurerm_application_insights.apim.instrumentation_key
  }
}

# APIM-level Application Insights diagnostic
resource "azurerm_api_management_diagnostic" "appinsights" {
  identifier               = "applicationinsights"
  resource_group_name      = var.resource_group_name
  api_management_name      = azurerm_api_management.apim.name
  api_management_logger_id = azurerm_api_management_logger.appinsights.id

  sampling_percentage       = 100.0
  always_log_errors         = true
  log_client_ip             = true
  verbosity                 = "information"
  http_correlation_protocol = "W3C"

  frontend_request {
    body_bytes = 0
    headers_to_log = []
  }

  frontend_response {
    body_bytes = 0
    headers_to_log = []
  }

  backend_request {
    body_bytes = 0
    headers_to_log = []
  }

  backend_response {
    body_bytes = 0
    headers_to_log = []
  }
}

# Diagnostic settings: send all APIM logs and metrics to Log Analytics
resource "azurerm_monitor_diagnostic_setting" "apim" {
  name                       = "diag-to-law"
  target_resource_id         = azurerm_api_management.apim.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.apim.id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
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

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.apim.id
}

output "application_insights_id" {
  value = azurerm_application_insights.apim.id
}

output "application_insights_instrumentation_key" {
  value     = azurerm_application_insights.apim.instrumentation_key
  sensitive = true
}

output "application_insights_connection_string" {
  value     = azurerm_application_insights.apim.connection_string
  sensitive = true
}
