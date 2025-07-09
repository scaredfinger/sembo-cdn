local SurrogateKeyMiddleware = require "modules.surrogate.middleware"

local cache_key_strategy_host_path = require "modules.cache.key_strategy_host_path"

local instance

--- @return table
local function init_surrogate()
    if instance then
        return instance
    end

    local tags_provider = require "handlers.utils.tags_provider"
    instance = SurrogateKeyMiddleware:new(tags_provider, cache_key_strategy_host_path)
    return instance
end

local cache = init_surrogate()
return cache
