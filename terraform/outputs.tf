output "resource_group_name" {
  description = "Resource group name"
  value       = azurerm_resource_group.rg.name
}

output "apim_name" {
  description = "API Management service name"
  value       = module.apim.apim_name
}

output "apim_gateway_url" {
  description = "API Management gateway URL"
  value       = module.apim.apim_gateway_url
}

output "redis_name" {
  description = "Redis cache name"
  value       = module.redis.redis_name
}

output "redis_hostname" {
  description = "Redis cache hostname"
  value       = module.redis.redis_hostname
}

output "batch_api_path" {
  description = "Batch API path"
  value       = module.apim_apis.batch_api_path
}

output "sticky_batch_api_path" {
  description = "Sticky Batch API path"
  value       = module.apim_sticky_apis.sticky_batch_api_path
}
