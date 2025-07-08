local parse_surrogate_key = require('modules.surrogate.surrogate_key_parser')

---@class SurrogateKeyMiddleware: Middleware
---@field tags_provider TagsProvider
---@field cache_key_strategy fun(request: Request): string
---@field __index SurrogateKeyMiddleware
local SurrogateKeyMiddleware = {}
SurrogateKeyMiddleware.__index = SurrogateKeyMiddleware

--- @param tags_provider TagsProvider
--- @param cache_key_strategy fun(request: Request): string
--- @return SurrogateKeyMiddleware
function SurrogateKeyMiddleware:new(tags_provider, cache_key_strategy)
    local instance = setmetatable({}, SurrogateKeyMiddleware)
    instance.tags_provider = tags_provider
    instance.cache_key_strategy = cache_key_strategy
    return instance
end

--- Associate cache key with surrogate tags
--- @param cache_key string
--- @param tags table<integer, string>
function SurrogateKeyMiddleware:_assign_tags_to_cache_key(cache_key, tags)
    for _, tag in ipairs(tags) do
        -- Use infinite TTL (nil) as requested
        self.tags_provider:add_key_to_tag(cache_key, tag)
    end
end

---@param request Request
---@param next fun(request: Request): Response A function to call the next middleware or handler
---@return Response
function SurrogateKeyMiddleware:execute(request, next)
    -- Get response from next middleware/handler
    local response = next(request)
    
    -- Check for Surrogate-Key header in response
    local surrogate_key_header = response.headers["Surrogate-Key"]
    if not surrogate_key_header then
        -- No surrogate keys, return response unchanged
        return response
    end
    
    -- Parse surrogate keys from header
    local tags = parse_surrogate_key(surrogate_key_header)
    if #tags == 0 then
        -- No valid tags found, return response unchanged
        return response
    end
    
    -- Generate cache key for this request
    local cache_key = self.cache_key_strategy(request)
    
    -- Associate cache key with tags
    self:_assign_tags_to_cache_key(cache_key, tags)
    
    return response
end

return SurrogateKeyMiddleware
