local Response = require "modules.http.response"

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
                locals = response.locals,
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

    local cached = self.provider:get(cache_key)

    if cached then
        local response = Response:new(
            cached.status,
            cached.body,
            cached.headers
        )

        local is_not_stale = cached.stale_at >= request.timestamp
        if is_not_stale then
            local cache_ttl = cached.expires_at - request.timestamp
            local cache_tts = cached.stale_at - request.timestamp
            local cache_age = request.timestamp - cached.timestamp

            response.headers["X-Cache"] = "HIT"
            response.headers["X-Cache-Age"] = tostring(cache_age)
            response.headers["X-Cache-TTL"] = tostring(cache_ttl)
            response.headers["X-Cache-TTS"] = tostring(cache_tts)

            response.locals.cache_state = "hit"
            response.locals.cache_age = cache_age
            response.locals.cache_ttl = cache_ttl
            response.locals.cache_tts = cache_tts

            return response
        end

        local is_stale_but_not_expired = cached.expires_at >= request.timestamp
        if is_stale_but_not_expired then
            local cache_ttl = cached.expires_at - request.timestamp

            response.headers["X-Cache"] = "STALE"
            response.headers["X-Cache-Age"] = tostring(request.timestamp - cached.timestamp)
            response.headers["X-Cache-TTL"] = tostring(cache_ttl)
            response.headers["X-Cache-TTS"] = "0"

            response.locals.cache_state = "stale"
            response.locals.cache_ttl = cache_ttl
            response.locals.cache_tts = 0

            self.defer(function()
                local updated_response = next(request)
                self:_store_response_in_cache(cache_key, updated_response, request)
            end)

            return response
        end
    end

    local next_response = next(request)
    local response_to_cache = next_response:clone()
    self:_store_response_in_cache(cache_key, response_to_cache, request)

    next_response.headers["X-Cache"] = "MISS"
    next_response.headers["X-Cache-Age"] = "0"

    next_response.locals.cache_state = "miss"
    next_response.locals.cache_ttl = 0
    next_response.locals.cache_tts = 0

    return next_response
end

return CacheMiddleware
