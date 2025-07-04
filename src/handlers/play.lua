local cjson = require "cjson"

local config = require "modules.config"
local RedisCacheProvider = require "modules.cache.providers.redis_cache_provider"

local get_or_create_redis_client = require "handlers.main.redis"

local redis_config = config.get_redis_config()
local redis_client

local redis_connection = get_or_create_redis_client(redis_client, redis_config)
if not redis_connection then
    ngx.log(ngx.ERR, "Cannot initialize cache without Redis connection")
    error("Failed to initialize Redis client")
end

local redis_provider = RedisCacheProvider:new(redis_connection)
-- redis_provider:set('key:123', { name = 'test', value = 42 }, 120, 3600)
local value = redis_provider:get('key:123')

ngx.status = 200
ngx.header["Content-Type"] = "application/json"
ngx.print(cjson.encode({
  value,
}))