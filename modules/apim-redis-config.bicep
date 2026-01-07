param apimName string
param redisId string
param redisHostName string
param redisSslPort int

resource apim 'Microsoft.ApiManagement/service@2023-05-01-preview' existing = {
  name: apimName
}

resource redis 'Microsoft.Cache/redis@2023-08-01' existing = {
  name: split(redisId, '/')[8]
}

resource redisCache 'Microsoft.ApiManagement/service/caches@2023-05-01-preview' = {
  name: 'redis-session-cache'
  parent: apim
  properties: {
    description: 'Redis cache for session affinity'
    connectionString: '${redisHostName}:${redisSslPort},password=${redis.listKeys().primaryKey},ssl=True,abortConnect=False'
    useFromLocation: apim.location
  }
}

output cacheId string = redisCache.id
