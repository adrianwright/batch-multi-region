variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
  sensitive   = true
}

variable "publisher_name" {
  description = "APIM publisher name"
  type        = string
  default     = "AI Platform"
}

variable "publisher_email" {
  description = "APIM publisher email"
  type        = string
  default     = "platform@example.com"
}

variable "foundry_resource_group_name" {
  description = "Resource group name containing the foundry resources"
  type        = string
  default     = "rg-batch-sticky"
}

variable "foundry_east_us_2_name" {
  description = "Name of the East US 2 foundry resource"
  type        = string
  default     = "batch-sticky-east-us-2"
}

variable "foundry_west_us_3_name" {
  description = "Name of the West US 3 foundry resource"
  type        = string
  default     = "batch-sticky-west-us-3"
}

variable "foundry_east_us_2_url" {
  description = "Backend URL for East US 2 foundry (including /openai/v1 path)"
  type        = string
  sensitive   = true
}

variable "foundry_west_us_3_url" {
  description = "Backend URL for West US 3 foundry (including /openai/v1 path)"
  type        = string
  sensitive   = true
}
