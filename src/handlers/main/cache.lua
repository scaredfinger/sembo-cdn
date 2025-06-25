local RedisCacheProvider = require "modules.cache.providers.redis_cache_provider"
local CacheMiddleware = require "modules.cache.cache_middleware"

local cache_key_strategy_host_path = require "modules.cache.cache_key_strategy_host_path"
local cache_control_parser = require "modules.cache.cache_control_parser"
local get_or_create_redis_client = require "handlers.main.redis"

local config = require("modules.config")

local redis_config = config.get_redis_config()

---@type table
local redis_client
local cache_instance

---@return function
local function create_defer_function()
    return function(fn)
        ngx.timer.at(0, fn)
    end
end

---@return table
local function init_cache()
    if cache_instance then
        return cache_instance
    end

    local redis_connection = get_or_create_redis_client(redis_client, redis_config)
    if not redis_connection then
        ngx.log(ngx.ERR, "Cannot initialize cache without Redis connection")
        error("Failed to initialize Redis client")
    end

    redis_client = redis_connection

    local redis_provider = RedisCacheProvider:new(redis_connection)
    local defer_function = create_defer_function()

    cache_instance = CacheMiddleware:new(redis_provider, cache_key_strategy_host_path, cache_control_parser,
    defer_function)
    return cache_instance
end

local cache_proxy = {
    execute = function(self, request, upstream_fn)
        local initialized_cache = init_cache()
        return initialized_cache:execute(request, upstream_fn)
    end
}

return cache_proxy
