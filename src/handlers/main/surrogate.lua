local SurrogateKeyMiddleware = require "modules.surrogate.middleware"

local cache_key_strategy_host_path = require "modules.cache.key_strategy_host_path"

local tags_provider = require "handlers.utils.tags_provider"
local instance = SurrogateKeyMiddleware:new(tags_provider, cache_key_strategy_host_path)
return instance
