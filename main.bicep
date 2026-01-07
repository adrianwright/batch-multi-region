// Simple APIM deployment
targetScope = 'subscription'

@description('Environment name')
param environment string = 'dev'

@description('Location for APIM')
param location string = 'eastus'

@description('APIM publisher name')
param publisherName string = 'AI Platform'

@description('APIM publisher email')
param publisherEmail string = 'platform@example.com'

// Create resource group
resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: 'rg-apim-${environment}'
  location: location
}

// Deploy APIM as a module
module apimModule 'modules/apim.bicep' = {
  name: 'apim-deployment'
  scope: rg
  params: {
    location: location
    apimName: 'apim-${environment}-${uniqueString(rg.id)}'
    publisherEmail: publisherEmail
    publisherName: publisherName
  }
}

// Reference to the external foundry resource group
resource foundryRg 'Microsoft.Resources/resourceGroups@2023-07-01' existing = {
  name: 'rg-batch-sticky'
}

// Grant APIM access to foundries via role assignment (skip if already exists)
/*
module roleAssignmentEastUS2 'modules/role-assignment.bicep' = {
  name: 'role-assignment-east-us-2'
  scope: foundryRg
  params: {
    apimPrincipalId: apimModule.outputs.apimPrincipalId
    foundryResourceId: apimModule.outputs.foundryEastUS2Id
  }
}

module roleAssignmentWestUS3 'modules/role-assignment.bicep' = {
  name: 'role-assignment-west-us-3'
  scope: foundryRg
  params: {
    apimPrincipalId: apimModule.outputs.apimPrincipalId
    foundryResourceId: apimModule.outputs.foundryWestUS3Id
  }
}
*/

// Deploy Redis cache
module redisModule 'modules/redis.bicep' = {
  name: 'redis-deployment'
  scope: rg
  params: {
    location: location
    redisName: 'redis-${environment}-${uniqueString(rg.id)}'
  }
}

// Configure APIM to use Redis
module apimRedisConfig 'modules/apim-redis-config.bicep' = {
  name: 'apim-redis-config'
  scope: rg
  params: {
    apimName: apimModule.outputs.apimName
    redisId: redisModule.outputs.redisId
    redisHostName: redisModule.outputs.redisHostName
    redisSslPort: redisModule.outputs.redisSslPort
  }
}

output apimName string = apimModule.outputs.apimName
output apimEndpoint string = apimModule.outputs.apimGatewayUrl
output resourceGroup string = rg.name
output redisName string = redisModule.outputs.redisName
output redisHostName string = redisModule.outputs.redisHostName
