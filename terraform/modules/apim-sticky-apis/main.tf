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

# ===== OpenAI Batch API with Sticky Sessions (Redis-based) =====

resource "azurerm_api_management_api" "sticky_batch_api" {
  name                  = "openai-batch-sticky"
  resource_group_name   = var.resource_group_name
  api_management_name   = var.apim_name
  revision              = "1"
  display_name          = "OpenAI Batch API (Sticky Sessions)"
  path                  = "openai-sticky"
  protocols             = ["https"]
  description           = "OpenAI Batch API with region affinity via Redis"
  subscription_required = true
}

# Sticky Upload file operation
resource "azurerm_api_management_api_operation" "sticky_upload_file" {
  operation_id        = "sticky-upload-file"
  api_name            = azurerm_api_management_api.sticky_batch_api.name
  api_management_name = var.apim_name
  resource_group_name = var.resource_group_name
  display_name        = "Upload File (Sticky)"
  method              = "POST"
  url_template        = "/files"
  description         = "Upload a file and store backend affinity"
}

# Sticky Submit batch operation
resource "azurerm_api_management_api_operation" "sticky_submit_batch" {
  operation_id        = "sticky-submit-batch"
  api_name            = azurerm_api_management_api.sticky_batch_api.name
  api_management_name = var.apim_name
  resource_group_name = var.resource_group_name
  display_name        = "Submit Batch (Sticky)"
  method              = "POST"
  url_template        = "/batches"
  description         = "Submit a batch job to the same region as the file"
}

# Sticky Get batch operation
resource "azurerm_api_management_api_operation" "sticky_get_batch" {
  operation_id        = "sticky-get-batch"
  api_name            = azurerm_api_management_api.sticky_batch_api.name
  api_management_name = var.apim_name
  resource_group_name = var.resource_group_name
  display_name        = "Get Batch (Sticky)"
  method              = "GET"
  url_template        = "/batches/{batch_id}"
  description         = "Get batch status from the same region"

  template_parameter {
    name     = "batch_id"
    required = true
    type     = "string"
  }
}

# Sticky API policy with Redis-based session affinity
resource "azurerm_api_management_api_policy" "sticky_batch_api_policy" {
  api_name            = azurerm_api_management_api.sticky_batch_api.name
  api_management_name = var.apim_name
  resource_group_name = var.resource_group_name

  xml_content = <<XML
<policies>
  <inbound>
    <base />
    <authentication-managed-identity resource="https://cognitiveservices.azure.com" />
    <choose>
      <!-- File Upload: Random backend selection and store in Redis -->
      <when condition="@(context.Operation.Method == &quot;POST&quot; &amp;&amp; context.Request.Url.Path.EndsWith(&quot;/files&quot;))">
        <set-variable name="selectedBackend" value="@(new Random().Next(2) == 0 ? &quot;foundry-batch-sticky-east-us-2&quot; : &quot;foundry-batch-sticky-west-us-3&quot;)" />
        <set-backend-service backend-id="@((string)context.Variables[&quot;selectedBackend&quot;])" />
      </when>
      <!-- Batch Submit: Lookup backend by file_id from request body -->
      <when condition="@(context.Operation.Method == &quot;POST&quot; &amp;&amp; context.Request.Url.Path.EndsWith(&quot;/batches&quot;))">
        <set-variable name="requestBody" value="@(context.Request.Body.As&lt;JObject&gt;(preserveContent: true))" />
        <set-variable name="fileId" value="@(((JObject)context.Variables[&quot;requestBody&quot;])[&quot;input_file_id&quot;].ToString())" />
        <cache-lookup-value key="@(&quot;backend:&quot; + (string)context.Variables[&quot;fileId&quot;])" variable-name="cachedBackend" caching-type="external" />
        <choose>
          <when condition="@(context.Variables.ContainsKey(&quot;cachedBackend&quot;))">
            <set-backend-service backend-id="@((string)context.Variables[&quot;cachedBackend&quot;])" />
          </when>
          <otherwise>
            <!-- Fallback to random if not found -->
            <set-variable name="selectedBackend" value="@(new Random().Next(2) == 0 ? &quot;foundry-batch-sticky-east-us-2&quot; : &quot;foundry-batch-sticky-west-us-3&quot;)" />
            <set-backend-service backend-id="@((string)context.Variables[&quot;selectedBackend&quot;])" />
          </otherwise>
        </choose>
      </when>
      <!-- Batch Get: Lookup backend by batch_id from URL -->
      <when condition="@(context.Operation.Method == &quot;GET&quot; &amp;&amp; context.Request.Url.Path.Contains(&quot;/batches/&quot;))">
        <set-variable name="batchId" value="@(context.Request.MatchedParameters[&quot;batch_id&quot;])" />
        <cache-lookup-value key="@(&quot;backend:&quot; + (string)context.Variables[&quot;batchId&quot;])" variable-name="cachedBackend" caching-type="external" />
        <choose>
          <when condition="@(context.Variables.ContainsKey(&quot;cachedBackend&quot;))">
            <set-backend-service backend-id="@((string)context.Variables[&quot;cachedBackend&quot;])" />
          </when>
          <otherwise>
            <!-- Fallback to random if not found -->
            <set-variable name="selectedBackend" value="@(new Random().Next(2) == 0 ? &quot;foundry-batch-sticky-east-us-2&quot; : &quot;foundry-batch-sticky-west-us-3&quot;)" />
            <set-backend-service backend-id="@((string)context.Variables[&quot;selectedBackend&quot;])" />
          </otherwise>
        </choose>
      </when>
      <otherwise>
        <!-- Default: use first backend -->
        <set-backend-service backend-id="foundry-batch-sticky-east-us-2" />
      </otherwise>
    </choose>
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
    <set-header name="X-Backend-Region" exists-action="override">
      <value>@(context.Request.Url.Host.Contains(&quot;east-us-2&quot;) ? &quot;eastus2&quot; : context.Request.Url.Host.Contains(&quot;west-us-3&quot;) ? &quot;westus3&quot; : &quot;unknown&quot;)</value>
    </set-header>
    <choose>
      <!-- After file upload: Store file_id -> backend mapping -->
      <when condition="@(context.Operation.Method == &quot;POST&quot; &amp;&amp; context.Request.Url.Path.EndsWith(&quot;/files&quot;) &amp;&amp; context.Response.StatusCode == 201)">
        <set-variable name="responseBody" value="@(context.Response.Body.As&lt;JObject&gt;(preserveContent: true))" />
        <set-variable name="fileId" value="@(((JObject)context.Variables[&quot;responseBody&quot;])[&quot;id&quot;].ToString())" />
        <cache-store-value key="@(&quot;backend:&quot; + (string)context.Variables[&quot;fileId&quot;])" value="@((string)context.Variables[&quot;selectedBackend&quot;])" duration="86400" caching-type="external" />
      </when>
      <!-- After batch submit: Store batch_id -> backend mapping -->
      <when condition="@(context.Operation.Method == &quot;POST&quot; &amp;&amp; context.Request.Url.Path.EndsWith(&quot;/batches&quot;) &amp;&amp; context.Response.StatusCode == 200)">
        <set-variable name="responseBody" value="@(context.Response.Body.As&lt;JObject&gt;(preserveContent: true))" />
        <set-variable name="batchId" value="@(((JObject)context.Variables[&quot;responseBody&quot;])[&quot;id&quot;].ToString())" />
        <set-variable name="usedBackend" value="@(context.Variables.ContainsKey(&quot;cachedBackend&quot;) ? (string)context.Variables[&quot;cachedBackend&quot;] : (string)context.Variables[&quot;selectedBackend&quot;])" />
        <cache-store-value key="@(&quot;backend:&quot; + (string)context.Variables[&quot;batchId&quot;])" value="@((string)context.Variables[&quot;usedBackend&quot;])" duration="86400" caching-type="external" />
      </when>
    </choose>
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
XML
}

# ===== OpenAI Realtime & Chat API =====

resource "azurerm_api_management_api" "realtime_chat_api" {
  name                  = "openai-realtime-chat"
  resource_group_name   = var.resource_group_name
  api_management_name   = var.apim_name
  revision              = "1"
  display_name          = "OpenAI Realtime & Chat API"
  path                  = "openai-realtime"
  protocols             = ["https"]
  description           = "OpenAI Realtime and Chat API with session affinity"
  subscription_required = true
}

# Responses API operation
resource "azurerm_api_management_api_operation" "responses" {
  operation_id        = "responses"
  api_name            = azurerm_api_management_api.realtime_chat_api.name
  api_management_name = var.apim_name
  resource_group_name = var.resource_group_name
  display_name        = "Responses API"
  method              = "POST"
  url_template        = "/responses"
  description         = "Create a response using Azure Responses API"
}

# Chat completions operation
resource "azurerm_api_management_api_operation" "chat_completions" {
  operation_id        = "chat-completions"
  api_name            = azurerm_api_management_api.realtime_chat_api.name
  api_management_name = var.apim_name
  resource_group_name = var.resource_group_name
  display_name        = "Chat Completions"
  method              = "POST"
  url_template        = "/chat/completions"
  description         = "Create a chat completion"
}

# Embeddings operation
resource "azurerm_api_management_api_operation" "embeddings" {
  operation_id        = "embeddings"
  api_name            = azurerm_api_management_api.realtime_chat_api.name
  api_management_name = var.apim_name
  resource_group_name = var.resource_group_name
  display_name        = "Embeddings"
  method              = "POST"
  url_template        = "/embeddings"
  description         = "Create embeddings"
}

# Policy for Realtime and Chat API with session affinity
resource "azurerm_api_management_api_policy" "realtime_chat_api_policy" {
  api_name            = azurerm_api_management_api.realtime_chat_api.name
  api_management_name = var.apim_name
  resource_group_name = var.resource_group_name

  xml_content = <<XML
<policies>
  <inbound>
    <base />
    <authentication-managed-identity resource="https://cognitiveservices.azure.com" />
    <!-- Extract session identifier from header or generate one -->
    <set-variable name="sessionId" value="@(context.Request.Headers.GetValueOrDefault(&quot;X-Session-Id&quot;, context.Subscription.Key + &quot;:&quot; + context.Request.IpAddress))" />
    <!-- Lookup backend for this session -->
    <cache-lookup-value key="@(&quot;session-backend:&quot; + (string)context.Variables[&quot;sessionId&quot;])" variable-name="cachedBackend" caching-type="external" />
    <choose>
      <when condition="@(context.Variables.ContainsKey(&quot;cachedBackend&quot;))">
        <!-- Use cached backend for this session -->
        <set-backend-service backend-id="@((string)context.Variables[&quot;cachedBackend&quot;])" />
      </when>
      <otherwise>
        <!-- First request for this session: randomly select a backend -->
        <set-variable name="selectedBackend" value="@(new Random().Next(2) == 0 ? &quot;foundry-batch-sticky-east-us-2&quot; : &quot;foundry-batch-sticky-west-us-3&quot;)" />
        <set-backend-service backend-id="@((string)context.Variables[&quot;selectedBackend&quot;])" />
        <!-- Store the selected backend for this session (24 hour TTL) -->
        <cache-store-value key="@(&quot;session-backend:&quot; + (string)context.Variables[&quot;sessionId&quot;])" value="@((string)context.Variables[&quot;selectedBackend&quot;])" duration="86400" caching-type="external" />
      </otherwise>
    </choose>
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
    <!-- Return the session ID to the client for subsequent requests -->
    <set-header name="X-Session-Id" exists-action="override">
      <value>@((string)context.Variables[&quot;sessionId&quot;])</value>
    </set-header>
    <set-header name="X-Backend-Region" exists-action="override">
      <value>@(context.Request.Url.Host.Contains(&quot;east-us-2&quot;) ? &quot;eastus2&quot; : context.Request.Url.Host.Contains(&quot;west-us-3&quot;) ? &quot;westus3&quot; : &quot;unknown&quot;)</value>
    </set-header>
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
XML
}

output "sticky_batch_api_id" {
  value = azurerm_api_management_api.sticky_batch_api.id
}

output "sticky_batch_api_path" {
  value = azurerm_api_management_api.sticky_batch_api.path
}

output "realtime_chat_api_id" {
  value = azurerm_api_management_api.realtime_chat_api.id
}

output "realtime_chat_api_path" {
  value = azurerm_api_management_api.realtime_chat_api.path
}
