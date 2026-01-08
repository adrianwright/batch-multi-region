param location string
param apimName string
param publisherName string
param publisherEmail string
@secure()
param foundryEastUS2Url string
@secure()
param foundryWestUS3Url string

resource apim 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
  name: apimName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'Developer'
    capacity: 1
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
  }
}

// Backend for the first foundry (East US 2)
resource backendEastUS2 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = {
  name: 'foundry-batch-sticky-east-us-2'
  parent: apim
  properties: {
    title: 'Foundry Backend - East US 2'
    description: 'Backend for AI Foundry in East US 2 (v1 API)'
    url: foundryEastUS2Url
    protocol: 'http'
  }
}

// Backend for the second foundry (West US 3)
resource backendWestUS3 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = {
  name: 'foundry-batch-sticky-west-us-3'
  parent: apim
  properties: {
    title: 'Foundry Backend - West US 3'
    description: 'Backend for AI Foundry in West US 3 (v1 API)'
    url: foundryWestUS3Url
    protocol: 'http'
  }
}


// Backend pool with random load balancing
resource backendPool 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = {
  name: 'foundry-pool'
  parent: apim
  dependsOn: [
    backendEastUS2
    backendWestUS3
  ]
  properties: {
    title: 'Foundry Backend Pool'
    description: 'Load balanced pool of foundry backends'
    type: 'Pool'
    pool: {
      services: [
        {
          id: '/backends/${backendEastUS2.name}'
        }
        {
          id: '/backends/${backendWestUS3.name}'
        }
      ]
    }
  }
}

// API for OpenAI Batch
resource batchApi 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = {
  name: 'openai-batch'
  parent: apim
  properties: {
    displayName: 'OpenAI Batch API'
    apiRevision: '1'
    description: 'OpenAI Batch API for asynchronous processing'
    subscriptionRequired: true
    path: 'openai'
    protocols: [
      'https'
    ]
  }
}

// Submit batch operation
resource submitBatchOp 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  name: 'submit-batch'
  parent: batchApi
  properties: {
    displayName: 'Submit Batch'
    method: 'POST'
    urlTemplate: '/batches'
    description: 'Submit a new batch job'
  }
}

// Get batch operation
resource getBatchOp 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  name: 'get-batch'
  parent: batchApi
  properties: {
    displayName: 'Get Batch'
    method: 'GET'
    urlTemplate: '/batches/{batch_id}'
    description: 'Get batch job status'
    templateParameters: [
      {
        name: 'batch_id'
        required: true
        type: 'string'
      }
    ]
  }
}

// Cancel batch operation
resource cancelBatchOp 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  name: 'cancel-batch'
  parent: batchApi
  properties: {
    displayName: 'Cancel Batch'
    method: 'POST'
    urlTemplate: '/batches/{batch_id}/cancel'
    description: 'Cancel a batch job'
    templateParameters: [
      {
        name: 'batch_id'
        required: true
        type: 'string'
      }
    ]
  }
}

// List batches operation
resource listBatchesOp 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  name: 'list-batches'
  parent: batchApi
  properties: {
    displayName: 'List Batches'
    method: 'GET'
    urlTemplate: '/batches'
    description: 'List all batch jobs'
  }
}

// Upload file operation
resource uploadFileOp 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  name: 'upload-file'
  parent: batchApi
  properties: {
    displayName: 'Upload File'
    method: 'POST'
    urlTemplate: '/files'
    description: 'Upload a file for batch processing'
  }
}

// List files operation
resource listFilesOp 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  name: 'list-files'
  parent: batchApi
  properties: {
    displayName: 'List Files'
    method: 'GET'
    urlTemplate: '/files'
    description: 'List all uploaded files'
  }
}

// Get file operation
resource getFileOp 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  name: 'get-file'
  parent: batchApi
  properties: {
    displayName: 'Get File'
    method: 'GET'
    urlTemplate: '/files/{file_id}'
    description: 'Get file details'
    templateParameters: [
      {
        name: 'file_id'
        required: true
        type: 'string'
      }
    ]
  }
}

// Delete file operation
resource deleteFileOp 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  name: 'delete-file'
  parent: batchApi
  properties: {
    displayName: 'Delete File'
    method: 'DELETE'
    urlTemplate: '/files/{file_id}'
    description: 'Delete a file'
    templateParameters: [
      {
        name: 'file_id'
        required: true
        type: 'string'
      }
    ]
  }
}

// Get file content operation
resource getFileContentOp 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  name: 'get-file-content'
  parent: batchApi
  properties: {
    displayName: 'Get File Content'
    method: 'GET'
    urlTemplate: '/files/{file_id}/content'
    description: 'Download file content'
    templateParameters: [
      {
        name: 'file_id'
        required: true
        type: 'string'
      }
    ]
  }
}

// Policy to route to backend pool with random load balancing
resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2023-05-01-preview' = {
  name: 'policy'
  parent: batchApi
  dependsOn: [
    backendPool
  ]
  properties: {
    value: '<policies><inbound><base /><authentication-managed-identity resource="https://cognitiveservices.azure.com" /><set-backend-service backend-id="foundry-pool" /></inbound><backend><base /></backend><outbound><base /><set-header name="X-Backend-Region" exists-action="override"><value>@(context.Request.Url.Host.Contains("east-us-2") ? "eastus2" : context.Request.Url.Host.Contains("west-us-3") ? "westus3" : "unknown")</value></set-header></outbound><on-error><base /></on-error></policies>'
  }
}

// Sticky API with session affinity
resource stickyBatchApi 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = {
  name: 'openai-batch-sticky'
  parent: apim
  properties: {
    displayName: 'OpenAI Batch API (Sticky Sessions)'
    apiRevision: '1'
    description: 'OpenAI Batch API with region affinity via Redis'
    subscriptionRequired: true
    path: 'openai-sticky'
    protocols: [
      'https'
    ]
  }
}

// Sticky Upload file operation
resource stickyUploadFileOp 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  name: 'sticky-upload-file'
  parent: stickyBatchApi
  properties: {
    displayName: 'Upload File (Sticky)'
    method: 'POST'
    urlTemplate: '/files'
    description: 'Upload a file and store backend affinity'
  }
}

// Sticky Submit batch operation
resource stickySubmitBatchOp 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  name: 'sticky-submit-batch'
  parent: stickyBatchApi
  properties: {
    displayName: 'Submit Batch (Sticky)'
    method: 'POST'
    urlTemplate: '/batches'
    description: 'Submit a batch job to the same region as the file'
  }
}

// Sticky Get batch operation
resource stickyGetBatchOp 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  name: 'sticky-get-batch'
  parent: stickyBatchApi
  properties: {
    displayName: 'Get Batch (Sticky)'
    method: 'GET'
    urlTemplate: '/batches/{batch_id}'
    description: 'Get batch status from the same region'
    templateParameters: [
      {
        name: 'batch_id'
        required: true
        type: 'string'
      }
    ]
  }
}

// Sticky API policy with Redis-based session affinity
resource stickyApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2023-05-01-preview' = {
  name: 'policy'
  parent: stickyBatchApi
  dependsOn: [
    backendEastUS2
    backendWestUS3
  ]
  properties: {
    value: '''<policies>
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
</policies>'''
  }
}

output apimName string = apim.name
output apimGatewayUrl string = apim.properties.gatewayUrl
output apimId string = apim.id
output batchApiPath string = batchApi.properties.path
output stickyBatchApiPath string = stickyBatchApi.properties.path
output apimPrincipalId string = apim.identity.principalId
output foundryEastUS2Id string = '/subscriptions/${subscription().subscriptionId}/resourceGroups/rg-batch-sticky/providers/Microsoft.CognitiveServices/accounts/batch-sticky-east-us-2'
output foundryWestUS3Id string = '/subscriptions/${subscription().subscriptionId}/resourceGroups/rg-batch-sticky/providers/Microsoft.CognitiveServices/accounts/batch-sticky-west-us-3'
