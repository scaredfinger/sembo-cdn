---@class CacheMiddleware: Middleware
---@field provider CacheProvider
---@field cache_key_strategy fun(request: Request): string
---@field cache_control_parser fun(cache_control_header_value: string): ParsedCacheControl
---@field __index CacheMiddleware
local CacheMiddleware = {}
CacheMiddleware.__index = CacheMiddleware

--- @param provider CacheProvider
--- @param cache_key_strategy fun(request: Request): string
--- @param cache_control_parser fun(cache_control_header_value: string): ParsedCacheControl
--- @return CacheMiddleware
function CacheMiddleware:new(provider, cache_key_strategy, cache_control_parser)
    local instance = setmetatable({}, CacheMiddleware)
    instance.provider = provider
    instance.cache_key_strategy = cache_key_strategy
    instance.cache_control_parser = cache_control_parser
    return instance
end

---@param request Request
---@param next fun(request: Request): Response A function to call the next middleware or handler
function CacheMiddleware:execute(request, next)
    if request.method ~= "GET" then
        return next(request)
    end

    local cache_key = self.cache_key_strategy(request)

    local cached_response = self.provider:get(cache_key)

    if cached_response then
        if cached_response.stale_at >= request.timestamp then
            return cached_response
        end
        if cached_response.expires_at >= request.timestamp then
            return cached_response
        end
    end

    local next_response = next(request)

    if (next_response.headers["Cache-Control"] ~= nil) then
        local cache_control_header_value = next_response.headers["Cache-Control"]
        local parsed_cache_control = self.cache_control_parser(cache_control_header_value)

        if parsed_cache_control.no_cache or parsed_cache_control.no_store then
            return next_response
        end

        self.provider:set(cache_key, {
            body = next_response.body,
            headers = next_response.headers,
            status = next_response.status,
            stale_at = request.timestamp + parsed_cache_control.max_age,
            expires_at = request.timestamp + parsed_cache_control.stale_while_revalidate,
        },
        parsed_cache_control.max_age,
        parsed_cache_control.stale_while_revalidate)

        return next_response
    end

    return next_response
end

return CacheMiddleware