local RedisCacheProvider = require("modules.cache.providers.redis_cache_provider")
local CacheMiddleware = require("modules.cache.cache_middleware")
local cache_key_strategy_host_path = require("modules.cache.cache_key_strategy_host_path")
local cache_control_parser = require("modules.cache.cache_control_parser")

local config = require("modules.config")

local redis_config = config.get_redis_config()

---@type table Redis client instance
local redis_client
local cache_instance

---Initialize Redis client with proper error handling
---@return table|nil Redis client or nil on failure
local function get_or_create_redis_client()
    if redis_client then
        -- Test connection health
        local ok, err = redis_client:ping()
        if ok then
            return redis_client
        else
            ngx.log(ngx.WARN, "Redis connection unhealthy, reconnecting: ", err)
            redis_client = nil
        end
    end

    local redis = require("resty.redis")
    local client = redis:new()
    client:set_timeout(redis_config.timeout)
    
    local ok, err = client:connect(redis_config.host, redis_config.port)
    if not ok then
        ngx.log(ngx.ERR, "Failed to connect to Redis: ", err)
        return nil
    end

    if redis_config.password then
        local ok, err = client:auth(redis_config.password)
        if not ok then
            ngx.log(ngx.ERR, "Failed to authenticate with Redis: ", err)
            return nil
        end
    end

    if redis_config.database and redis_config.database > 0 then
        local ok, err = client:select(redis_config.database)
        if not ok then
            ngx.log(ngx.ERR, "Failed to select Redis database: ", err)
            return nil
        end
    end

    redis_client = client
    return redis_client
end

---Initialize cache instance
---@return table Cache middleware instance
local function init_cache()
    if cache_instance then
        return cache_instance
    end

    local redis = get_or_create_redis_client()
    if not redis then
        ngx.log(ngx.ERR, "Cannot initialize cache without Redis connection")
        error("Failed to initialize Redis client")
    end

    local redis_provider = RedisCacheProvider:new(redis)
    
    local defer = function (fn)
        ngx.timer.at(0, fn)
    end

    cache_instance = CacheMiddleware:new(redis_provider, cache_key_strategy_host_path, cache_control_parser, defer)
    return cache_instance
end

-- Create a proxy object that initializes cache on first use
local cache_proxy = {
    execute = function(self, request, upstream_fn)
        local cache = init_cache()
        return cache:execute(request, upstream_fn)
    end
}

-- Export the proxy instance
return cache_proxy
