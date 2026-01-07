@description('Location for the Redis cache')
param location string

@description('Redis cache name')
param redisName string

resource redis 'Microsoft.Cache/redis@2023-08-01' = {
  name: redisName
  location: location
  properties: {
    sku: {
      name: 'Basic'
      family: 'C'
      capacity: 0
    }
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
    redisConfiguration: {}
  }
}

output redisId string = redis.id
output redisName string = redis.name
output redisHostName string = redis.properties.hostName
output redisSslPort int = redis.properties.sslPort
