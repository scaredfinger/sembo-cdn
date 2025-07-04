---@class CacheMiddleware: Middleware
---@field provider CacheProvider
---@field cache_key_strategy fun(request: Request): string
---@field cache_control_parser fun(cache_control_header_value: string): ParsedCacheControl
---@field defer fun(callback: fun()): nil
---@field __index CacheMiddleware
local CacheMiddleware = {}
CacheMiddleware.__index = CacheMiddleware

--- @param provider CacheProvider
--- @param cache_key_strategy fun(request: Request): string
--- @param cache_control_parser fun(cache_control_header_value: string): ParsedCacheControl
--- @param defer fun(callback: fun()): nil
--- @return CacheMiddleware
function CacheMiddleware:new(provider, cache_key_strategy, cache_control_parser, defer)
    local instance = setmetatable({}, CacheMiddleware)
    instance.provider = provider
    instance.cache_key_strategy = cache_key_strategy
    instance.cache_control_parser = cache_control_parser
    instance.defer = defer
    return instance
end

---@private
---@param cache_key string
---@param response Response
---@param request Request
function CacheMiddleware:_store_response_in_cache(cache_key, response, request)    
    if (response.headers["Cache-Control"] ~= nil) then
        local cache_control_header_value = response.headers["Cache-Control"]
        local parsed_cache_control = self.cache_control_parser(cache_control_header_value)

        if parsed_cache_control.no_cache or parsed_cache_control.no_store then
            return
        end

        response.headers["X-Cache-TTL"] = tostring(parsed_cache_control.stale_while_revalidate)
        response.headers["X-Cache-TTS"] = tostring(parsed_cache_control.max_age)

        self.provider:set(cache_key, {
            body = response.body,
            headers = response.headers,
            status = response.status,
            timestamp = request.timestamp,
            stale_at = request.timestamp + parsed_cache_control.max_age,
            expires_at = request.timestamp + parsed_cache_control.stale_while_revalidate,
        },
        parsed_cache_control.max_age,
        parsed_cache_control.stale_while_revalidate)
    end
end

---@param request Request
---@param next fun(request: Request): Response A function to call the next middleware or handler
function CacheMiddleware:execute(request, next)
    if request.method ~= "GET" then
        return next(request)
    end

    local cache_key = self.cache_key_strategy(request)

    ngx.log(ngx.DEBUG, "Cache key: ", cache_key)

    local cached_response = self.provider:get(cache_key)

    if cached_response then
        local is_not_stale = cached_response.stale_at >= request.timestamp
        if is_not_stale then
            cached_response.headers["X-Cache"] = "HIT"
            cached_response.headers["X-Cache-Age"] = tostring(request.timestamp - cached_response.timestamp)
            cached_response.headers["X-Cache-TTL"] = tostring(cached_response.expires_at - request.timestamp)
            cached_response.headers["X-Cache-TTS"] = tostring(cached_response.stale_at - request.timestamp)

            return cached_response
        end

        local is_stale_but_not_expired = cached_response.expires_at >= request.timestamp
        if is_stale_but_not_expired then
            cached_response.headers["X-Cache"] = "STALE"
            cached_response.headers["X-Cache-Age"] = tostring(request.timestamp - cached_response.timestamp)
            cached_response.headers["X-Cache-TTL"] = tostring(cached_response.expires_at - request.timestamp)
            cached_response.headers["X-Cache-TTS"] = "0"

            self.defer(function()
                local updated_response = next(request)
                self:_store_response_in_cache(cache_key, updated_response, request)
            end)
            
            return cached_response
        end
    end

    local next_response = next(request)

    next_response.headers["X-Cache"] = "MISS"
    next_response.headers["X-Cache-Age"] = "0"

    self:_store_response_in_cache(cache_key, next_response, request)

    return next_response
end

return CacheMiddleware