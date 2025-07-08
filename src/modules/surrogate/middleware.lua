---@class SurrogateKeyMiddleware: Middleware
---@field provider CacheProvider
---@field __index SurrogateKeyMiddleware
local SurrogateKeyMiddleware = {}
SurrogateKeyMiddleware.__index = SurrogateKeyMiddleware

--- @param provider CacheProvider
--- @return SurrogateKeyMiddleware
function SurrogateKeyMiddleware:new(provider)
    local instance = setmetatable({}, SurrogateKeyMiddleware)
    instance.provider = provider
    return instance
end

---@param request Request
---@param next fun(request: Request): Response A function to call the next middleware or handler
---@return Response
function SurrogateKeyMiddleware:execute(request, next)
    -- For now, just delegate to next middleware/handler
    return next(request)
end

return SurrogateKeyMiddleware
