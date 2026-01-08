variable "apim_principal_id" {
  description = "APIM system-assigned managed identity principal ID"
  type        = string
}

variable "foundry_resource_ids" {
  description = "List of Foundry resource IDs to grant access to"
  type        = list(string)
}

variable "role_definition_name" {
  description = "Role definition name (e.g., 'Cognitive Services OpenAI User')"
  type        = string
  default     = "Cognitive Services OpenAI User"
}

# Cognitive Services OpenAI User role
data "azurerm_role_definition" "cognitive_services_openai_user" {
  name = var.role_definition_name
}

# Assign role for each foundry resource
resource "azurerm_role_assignment" "apim_to_foundry" {
  for_each = toset(var.foundry_resource_ids)

  scope                            = each.value
  role_definition_id               = data.azurerm_role_definition.cognitive_services_openai_user.id
  principal_id                     = var.apim_principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

output "role_assignment_ids" {
  value = [for ra in azurerm_role_assignment.apim_to_foundry : ra.id]
}
