
local RedisCacheProvider = require "modules.cache.providers.redis_cache_provider"
local CacheMiddleware = require "modules.cache.middleware"

local cache_key_strategy_host_path = require "modules.cache.key_strategy_host_path"
local cache_control_parser = require "modules.cache.cache_control_parser"

local config = require "modules.config"

local redis_config = config.get_redis_config()

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

    local redis_provider = RedisCacheProvider:new(open_connection, close_connection, ngx.null)
    local defer_function = create_defer_function()

    cache_instance = CacheMiddleware:new(redis_provider, cache_key_strategy_host_path, cache_control_parser,
    defer_function)
    return cache_instance
end

local cache = init_cache()
return cache