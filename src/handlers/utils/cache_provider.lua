local RedisCacheStorage = require "modules.cache.providers.redis_cache_storage"

local config = require "utils.config"
local redis_config = config.get_redis_config()

local function open_connection()
  local redis = require("resty.redis")
  local redis_connection = redis:new()
  redis_connection:set_timeout(config.timeout)
  redis_connection:connect(
    redis_config.host,
    redis_config.port or 6379
  )
  return redis_connection
end

local function close_connection(connection)
  if ngx.get_phase() == "timer" then
    connection:close()
  else
    connection:set_keepalive(10000, 100)
  end
  return true
end

local redis_cache_provider = RedisCacheStorage:new(open_connection, close_connection, ngx.null)

local CacheStorageCompressionDecorator = require "modules.cache.providers.cache_storage_compression_decorator"
local br = require "modules.compression.br"
local cache_provider_gzip_decorator = CacheStorageCompressionDecorator:new(
  redis_cache_provider,
  br.encode,
  br.decode
)

local CacheStorageMetricsDecorator = require "modules.cache.providers.cache_storage_metrics_decorator"
local metrics = require "handlers.utils.metrics.instance"
local metrics_name = require "handlers.utils.metrics.names"
local cache_storage_metrics_decorator = CacheStorageMetricsDecorator:new(
  cache_provider_gzip_decorator,
  metrics,
  metrics_name.cache_operation,
  "redis"
)

local JsonCacheProvider = require "modules.cache.providers.json_cache_provider"
local json_cache_provider = JsonCacheProvider:new(cache_storage_metrics_decorator)
return json_cache_provider