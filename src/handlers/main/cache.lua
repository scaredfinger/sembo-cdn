local CacheMiddleware = require "modules.cache.middleware"

local cache_key_strategy_host_path = require "modules.cache.key_strategy_host_path"
local cache_control_parser = require "modules.cache.cache_control_parser"

--- @return function
local function create_defer_function()
    return function(fn)
        ngx.timer.at(0, fn)
    end
end

local defer_function = create_defer_function()

local cache_provider = require "handlers.utils.cache_provider"
local cache_instance = CacheMiddleware:new(
    cache_provider,
    cache_key_strategy_host_path,
    cache_control_parser,
    defer_function
)
return cache_instance
