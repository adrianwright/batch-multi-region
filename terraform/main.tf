# Main Terraform configuration for multi-region batch API infrastructure

# Resource group
resource "azurerm_resource_group" "rg" {
  name     = "rg-apim-${var.environment}"
  location = var.location
}

# Deploy Redis cache
module "redis" {
  source = "./modules/redis"

  location            = var.location
  redis_name          = "redis-${var.environment}-${substr(sha256(azurerm_resource_group.rg.id), 0, 8)}"
  resource_group_name = azurerm_resource_group.rg.name

  depends_on = [azurerm_resource_group.rg]
}

# Deploy APIM
module "apim" {
  source = "./modules/apim"

  location               = var.location
  apim_name              = "apim-${var.environment}-${substr(sha256(azurerm_resource_group.rg.id), 0, 8)}"
  publisher_name         = var.publisher_name
  publisher_email        = var.publisher_email
  resource_group_name    = azurerm_resource_group.rg.name
  foundry_east_us_2_url  = var.foundry_east_us_2_url
  foundry_west_us_3_url  = var.foundry_west_us_3_url

  depends_on = [azurerm_resource_group.rg]
}

# Configure APIM to use Redis cache
module "apim_redis_config" {
  source = "./modules/apim-redis-config"

  apim_name                = module.apim.apim_name
  resource_group_name      = azurerm_resource_group.rg.name
  redis_id                 = module.redis.redis_id
  redis_hostname           = module.redis.redis_hostname
  redis_ssl_port           = module.redis.redis_ssl_port
  redis_primary_access_key = module.redis.redis_primary_access_key
  apim_location            = var.location

  depends_on = [module.apim, module.redis]
}

# Deploy standard Batch API (random load balancing)
module "apim_apis" {
  source = "./modules/apim-apis"

  apim_name           = module.apim.apim_name
  resource_group_name = azurerm_resource_group.rg.name
  apim_id             = module.apim.apim_id

  depends_on = [module.apim]
}

# Deploy Sticky Batch API and Realtime/Chat API (Redis-based affinity)
module "apim_sticky_apis" {
  source = "./modules/apim-sticky-apis"

  apim_name           = module.apim.apim_name
  resource_group_name = azurerm_resource_group.rg.name
  apim_id             = module.apim.apim_id

  depends_on = [module.apim, module.apim_redis_config]
}

# Reference to existing foundry resource group
data "azurerm_resource_group" "foundry_rg" {
  name = var.foundry_resource_group_name
}

# Construct foundry resource IDs
locals {
  foundry_east_us_2_id = "${data.azurerm_resource_group.foundry_rg.id}/providers/Microsoft.CognitiveServices/accounts/${var.foundry_east_us_2_name}"
  foundry_west_us_3_id = "${data.azurerm_resource_group.foundry_rg.id}/providers/Microsoft.CognitiveServices/accounts/${var.foundry_west_us_3_name}"
}

# Assign APIM managed identity access to foundry resources
module "role_assignments" {
  source = "./modules/role-assignments"

  apim_principal_id = module.apim.apim_principal_id
  foundry_resource_ids = [
    local.foundry_east_us_2_id,
    local.foundry_west_us_3_id
  ]

  depends_on = [module.apim]
}
