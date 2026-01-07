targetScope = 'resourceGroup'

param apimPrincipalId string
param foundryResourceId string

// Role assignment to grant APIM access to foundry
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(foundryResourceId, apimPrincipalId, 'Cognitive Services OpenAI Contributor')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a001fd3d-188f-4b5d-821b-7da978bf7442')
    principalId: apimPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output roleAssignmentId string = roleAssignment.id
