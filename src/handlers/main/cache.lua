local RedisCacheProvider = require("modules.cache.providers.redis_cache_provider")
local CacheMiddleware = require("modules.cache.cache_middleware")
local cache_key_strategy_host_path = require("modules.cache.cache_key_strategy_host_path")
local cache_control_parser = require("modules.cache.cache_control_parser")

local config = require("modules.config")

local redis_config = config.get_redis_config()

--- 
        -- host = get_env("REDIS_HOST", defaults.redis_host),
        -- port = tonumber(get_env("REDIS_PORT", defaults.redis_port)),
        -- timeout = defaults.redis_timeout,
        -- pool_size = defaults.redis_pool_size,
        -- backlog = defaults.redis_backlog,
        -- default_ttl = defaults.redis_default_ttl

---@type table Redis client instance
local redis_client

---Initialize Redis client
---@return table Redis client
local function init_redis_client()
    if redis_client then
        return redis_client
    end

    local redis = require("resty.redis")
    redis_client = redis:new()
    redis_client:set_timeout(redis_config.timeout)
    
    ngx.log(ngx.ERR, "Before")
    local ok, err = redis_client:connect(redis_config.host, redis_config.port)
    ngx.log(ngx.ERR, "After")
    if not ok then
        ngx.log(ngx.ERR, "Failed to connect to Redis: ", err)
        return nil
    end

    if config.redis.password then
        local ok, err = redis_client:auth(config.redis.password)
        if not ok then
            ngx.log(ngx.ERR, "Failed to authenticate with Redis: ", err)
            return nil
        end
    end

    if config.redis.database > 0 then
        local ok, err = redis_client:select(config.redis.database)
        if not ok then
            ngx.log(ngx.ERR, "Failed to select Redis database: ", err)
            return nil
        end
    end

    return redis_client
end

-- Initialize the Redis client
local redis = init_redis_client()
if not redis then
    error("Failed to initialize Redis client")
end

local cache = {}
return cache

-- -- Create the Redis cache provider
-- local redis_provider = RedisCacheProvider:new(redis)


-- local defer = function (fn)
--     ngx.timer.at(0, fn)
-- end

-- local cache = CacheMiddleware:new(redis_provider, cache_key_strategy_host_path, cache_control_parser, defer)

-- -- Export the singleton instance
-- return cache
