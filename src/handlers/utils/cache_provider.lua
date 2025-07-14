local RedisCacheProvider = require "modules.cache.providers.redis_cache_provider"

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

local redis_cache_provider = RedisCacheProvider:new(open_connection, close_connection, ngx.null)

local CacheProviderGzipDecorator = require "modules.cache.providers.cache_provider_gzip_decorator"
local cache_provider_gzip_decorator = CacheProviderGzipDecorator:new(
  redis_cache_provider,
  ngx.deflate,
  ngx.inflate,
  ngx.encode_base64,
  ngx.decode_base64
)

return cache_provider_gzip_decorator