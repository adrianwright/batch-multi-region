variable "apim_name" {
  description = "API Management service name"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "apim_id" {
  description = "API Management service ID"
  type        = string
}

# ===== OpenAI Batch API (Random Load Balancing) =====

resource "azurerm_api_management_api" "batch_api" {
  name                  = "openai-batch"
  resource_group_name   = var.resource_group_name
  api_management_name   = var.apim_name
  revision              = "1"
  display_name          = "OpenAI Batch API"
  path                  = "openai"
  protocols             = ["https"]
  description           = "OpenAI Batch API for asynchronous processing"
  subscription_required = true
}

# Submit batch operation
resource "azurerm_api_management_api_operation" "submit_batch" {
  operation_id        = "submit-batch"
  api_name            = azurerm_api_management_api.batch_api.name
  api_management_name = var.apim_name
  resource_group_name = var.resource_group_name
  display_name        = "Submit Batch"
  method              = "POST"
  url_template        = "/batches"
  description         = "Submit a new batch job"
}

# Get batch operation
resource "azurerm_api_management_api_operation" "get_batch" {
  operation_id        = "get-batch"
  api_name            = azurerm_api_management_api.batch_api.name
  api_management_name = var.apim_name
  resource_group_name = var.resource_group_name
  display_name        = "Get Batch"
  method              = "GET"
  url_template        = "/batches/{batch_id}"
  description         = "Get batch job status"

  template_parameter {
    name     = "batch_id"
    required = true
    type     = "string"
  }
}

# Cancel batch operation
resource "azurerm_api_management_api_operation" "cancel_batch" {
  operation_id        = "cancel-batch"
  api_name            = azurerm_api_management_api.batch_api.name
  api_management_name = var.apim_name
  resource_group_name = var.resource_group_name
  display_name        = "Cancel Batch"
  method              = "POST"
  url_template        = "/batches/{batch_id}/cancel"
  description         = "Cancel a batch job"

  template_parameter {
    name     = "batch_id"
    required = true
    type     = "string"
  }
}

# List batches operation
resource "azurerm_api_management_api_operation" "list_batches" {
  operation_id        = "list-batches"
  api_name            = azurerm_api_management_api.batch_api.name
  api_management_name = var.apim_name
  resource_group_name = var.resource_group_name
  display_name        = "List Batches"
  method              = "GET"
  url_template        = "/batches"
  description         = "List all batch jobs"
}

# Upload file operation
resource "azurerm_api_management_api_operation" "upload_file" {
  operation_id        = "upload-file"
  api_name            = azurerm_api_management_api.batch_api.name
  api_management_name = var.apim_name
  resource_group_name = var.resource_group_name
  display_name        = "Upload File"
  method              = "POST"
  url_template        = "/files"
  description         = "Upload a file for batch processing"
}

# List files operation
resource "azurerm_api_management_api_operation" "list_files" {
  operation_id        = "list-files"
  api_name            = azurerm_api_management_api.batch_api.name
  api_management_name = var.apim_name
  resource_group_name = var.resource_group_name
  display_name        = "List Files"
  method              = "GET"
  url_template        = "/files"
  description         = "List all uploaded files"
}

# Get file operation
resource "azurerm_api_management_api_operation" "get_file" {
  operation_id        = "get-file"
  api_name            = azurerm_api_management_api.batch_api.name
  api_management_name = var.apim_name
  resource_group_name = var.resource_group_name
  display_name        = "Get File"
  method              = "GET"
  url_template        = "/files/{file_id}"
  description         = "Get file details"

  template_parameter {
    name     = "file_id"
    required = true
    type     = "string"
  }
}

# Delete file operation
resource "azurerm_api_management_api_operation" "delete_file" {
  operation_id        = "delete-file"
  api_name            = azurerm_api_management_api.batch_api.name
  api_management_name = var.apim_name
  resource_group_name = var.resource_group_name
  display_name        = "Delete File"
  method              = "DELETE"
  url_template        = "/files/{file_id}"
  description         = "Delete a file"

  template_parameter {
    name     = "file_id"
    required = true
    type     = "string"
  }
}

# Get file content operation
resource "azurerm_api_management_api_operation" "get_file_content" {
  operation_id        = "get-file-content"
  api_name            = azurerm_api_management_api.batch_api.name
  api_management_name = var.apim_name
  resource_group_name = var.resource_group_name
  display_name        = "Get File Content"
  method              = "GET"
  url_template        = "/files/{file_id}/content"
  description         = "Download file content"

  template_parameter {
    name     = "file_id"
    required = true
    type     = "string"
  }
}

# Policy for random load balancing
resource "azurerm_api_management_api_policy" "batch_api_policy" {
  api_name            = azurerm_api_management_api.batch_api.name
  api_management_name = var.apim_name
  resource_group_name = var.resource_group_name

  xml_content = <<XML
<policies>
  <inbound>
    <base />
    <authentication-managed-identity resource="https://cognitiveservices.azure.com" />
    <set-backend-service backend-id="foundry-pool" />
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
    <set-header name="X-Backend-Region" exists-action="override">
      <value>@(context.Request.Url.Host.Contains("east-us-2") ? "eastus2" : context.Request.Url.Host.Contains("west-us-3") ? "westus3" : "unknown")</value>
    </set-header>
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
XML
}

output "batch_api_id" {
  value = azurerm_api_management_api.batch_api.id
}

output "batch_api_path" {
  value = azurerm_api_management_api.batch_api.path
}
