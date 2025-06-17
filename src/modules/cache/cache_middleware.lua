---@class CacheMiddleware: Middleware
---@field provider CacheProvider The cache provider instance
---@field cache_key_strategy fun(request: Request): string A function to generate a cache key based on the context
---@field __index CacheMiddleware
local CacheMiddleware = {}
CacheMiddleware.__index = CacheMiddleware

--- @param provider CacheProvider The cache provider to use
--- @param cache_key_strategy fun(request: Request): string A function to generate a cache key based on the context
--- @return CacheMiddleware
function CacheMiddleware:new(provider, cache_key_strategy)
    local instance = setmetatable({}, CacheMiddleware)
    instance.provider = provider
    instance.cache_key_strategy = cache_key_strategy
    return instance
end

---@param request Request
---@param next fun(request: Request): Response A function to call the next middleware or handler
function CacheMiddleware:execute(request, next)
    -- Check if the request is cacheable
    if request.method ~= "GET" then
        return next(request)
    end

    local next_response = next(request)


    return next_response
end

return CacheMiddleware