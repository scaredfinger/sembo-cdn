local Request = require "modules.http.request"

local upstream = require "handlers.main.upstream"

--- @return string, table, string, string, number
local function extract_request_metadata()
    local http_method = ngx.var.request_method
    local request_headers = ngx.req.get_headers()
    local request_uri = ngx.var.request_uri
    local request_host = request_headers["Host"] or ngx.var.host
    local current_timestamp = os.time()

    return http_method, request_headers, request_uri, request_host, current_timestamp
end

--- @param method string
--- @return boolean
local function should_read_request_body(method)
    return method ~= "GET" and method ~= "HEAD"
end

--- @param method string
--- @return string|nil
local function get_request_body_if_needed(method)
    if not should_read_request_body(method) then
        return nil
    end

    ngx.req.read_body()
    return ngx.req.get_body_data()
end

--- @return function
local function create_upstream_function()
    return function(req)
        return upstream:execute(req)
    end
end

--- @param response Response
--- @return nil
local function send_response_to_client(response)
    ngx.status = response.status or 200

    for key, value in pairs(response.headers) do
        ngx.header[key] = value
    end

    ngx.print(response.body)
end

local http_method, request_headers, request_uri, request_host, current_timestamp = extract_request_metadata()
local request_body = get_request_body_if_needed(http_method)

local incoming_request = Request:new(
    http_method,
    request_uri,
    request_headers,
    request_body,
    {},
    request_host,
    current_timestamp
)

local upstream_function = create_upstream_function()

local RedisCacheProvider = require "modules.cache.providers.redis_cache_provider"
local CacheMiddleware = require "modules.cache.cache_middleware"

local cache_key_strategy_host_path = require "modules.cache.cache_key_strategy_host_path"
local cache_control_parser = require "modules.cache.cache_control_parser"
local get_or_create_redis_client = require "handlers.main.redis"

local config = require "modules.config"

local redis_config = config.get_redis_config()

---@type table
local redis_client
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

    local redis_connection = get_or_create_redis_client(redis_client, redis_config)
    if not redis_connection then
        ngx.log(ngx.ERR, "Cannot initialize cache without Redis connection")
        error("Failed to initialize Redis client")
    end

    redis_client = redis_connection

    local redis_provider = RedisCacheProvider:new(redis_connection)
    local defer_function = create_defer_function()

    cache_instance = CacheMiddleware:new(redis_provider, cache_key_strategy_host_path, cache_control_parser,
    defer_function)
    return cache_instance
end

local function execute(request, upstream_fn)
    local initialized_cache = init_cache()
    return initialized_cache:execute(request, upstream_fn)
end

local cached_or_fresh_response = execute(incoming_request, upstream_function)

send_response_to_client(cached_or_fresh_response)
