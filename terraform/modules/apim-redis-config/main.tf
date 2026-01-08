variable "apim_name" {
  description = "API Management service name"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "redis_id" {
  description = "Redis cache resource ID"
  type        = string
}

variable "redis_hostname" {
  description = "Redis cache hostname"
  type        = string
}

variable "redis_ssl_port" {
  description = "Redis cache SSL port"
  type        = number
}

variable "redis_primary_access_key" {
  description = "Redis cache primary access key"
  type        = string
  sensitive   = true
}

variable "apim_location" {
  description = "API Management location"
  type        = string
}

resource "azurerm_api_management_redis_cache" "redis_cache" {
  name              = "redis-session-cache"
  api_management_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.ApiManagement/service/${var.apim_name}"
  connection_string = "${var.redis_hostname}:${var.redis_ssl_port},password=${var.redis_primary_access_key},ssl=True,abortConnect=False"
  description       = "Redis cache for session affinity"
  redis_cache_id    = var.redis_id
  cache_location    = var.apim_location
}

data "azurerm_client_config" "current" {}

output "cache_id" {
  value = azurerm_api_management_redis_cache.redis_cache.id
}
