using './main.bicep'

param environment = 'dev'
param location = 'eastus'
param publisherName = 'AI Platform'
param publisherEmail = 'platform@example.com'
param foundryEastUS2Url = 'https://batch-sticky-east-us-2.openai.azure.com/openai/v1'
param foundryWestUS3Url = 'https://batch-sticky-west-us-3.openai.azure.com/openai/v1'
