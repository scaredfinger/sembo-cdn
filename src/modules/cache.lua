local RedisCacheProvider = require("modules.providers.redis_cache_provider")
local CacheManager = require("modules.cache_manager")

-- Configuration (could be moved to a separate config file)
local config = {
    redis = {
        host = os.getenv("REDIS_HOST") or "localhost",
        port = tonumber(os.getenv("REDIS_PORT")) or 6379,
        password = os.getenv("REDIS_PASSWORD"),
        database = tonumber(os.getenv("REDIS_DB")) or 0,
        timeout = tonumber(os.getenv("REDIS_TIMEOUT")) or 1000,
        pool_size = tonumber(os.getenv("REDIS_POOL_SIZE")) or 10,
        max_idle_timeout = tonumber(os.getenv("REDIS_MAX_IDLE_TIMEOUT")) or 10000,
    }
}

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
    redis_client:set_timeout(config.redis.timeout)
    
    local ok, err = redis_client:connect(config.redis.host, config.redis.port)
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

-- Create the Redis cache provider
local redis_provider = RedisCacheProvider:new(redis)

-- Create and export the singleton CacheManager instance
---@type CacheManager
local cache_manager = CacheManager:new(redis_provider)

-- Export the singleton instance
return cache_manager
