variable "location" {
  description = "Location for the Redis cache"
  type        = string
}

variable "redis_name" {
  description = "Redis cache name"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

resource "azurerm_redis_cache" "redis" {
  name                          = var.redis_name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  capacity                      = 0
  family                        = "C"
  sku_name                      = "Basic"
  non_ssl_port_enabled          = false
  minimum_tls_version           = "1.2"
  public_network_access_enabled = true

  redis_configuration {}
}

output "redis_id" {
  value = azurerm_redis_cache.redis.id
}

output "redis_name" {
  value = azurerm_redis_cache.redis.name
}

output "redis_hostname" {
  value = azurerm_redis_cache.redis.hostname
}

output "redis_ssl_port" {
  value = azurerm_redis_cache.redis.ssl_port
}

output "redis_primary_access_key" {
  value     = azurerm_redis_cache.redis.primary_access_key
  sensitive = true
}
