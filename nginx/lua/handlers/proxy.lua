-- Main proxy handler
local http = require "resty.http"
local cache = require "modules.cache"
local metrics = require "modules.metrics"
local utils = require "modules.utils"

-- Get configuration
local backend_host = utils.get_env("BACKEND_HOST", "localhost")
local backend_port = utils.get_env("BACKEND_PORT", "3000")
local backend_url = "http://" .. backend_host .. ";" .. backend_port

-- Start timing
local start_time = ngx.now()

-- Get request details
local method = ngx.var.request_method
local uri = ngx.var.uri
local args = ngx.var.args or ""
local route_pattern = ngx.var.route_pattern or "unknown"

-- Generate cache key
local cache_key = utils.generate_cache_key(uri, args)
local cache_status = "none"

-- Try to get from cache for GET requests
if method == "GET" then
    local cached_response, cache_err = cache.get(cache_key)
    if cached_response and cache_err == "hit" then
        -- Serve from cache
        cache_status = "hit"
        
        -- Set response headers
        for key, value in pairs(cached_response.headers) do
            ngx.header[key] = value
        end
        ngx.header["X-Cache-Status"] = "HIT"
        
        -- Send response
        ngx.status = cached_response.status
        ngx.say(cached_response.body)
        
        -- Record metrics
        local response_time = ngx.now() - start_time
        metrics.record_request(route_pattern, method, cached_response.status, response_time, cache_status)
        
        utils.log("debug", "Served from cache: " .. cache_key)
        return
    else
        cache_status = "miss"
    end
end

-- Forward request to backend
local httpc = http.new()
httpc:set_timeout(30000) -- 30 seconds

-- Prepare request
local full_uri = uri
if args and args ~= "" then
    full_uri = uri .. "?" .. args
end

local backend_request_url = backend_url .. full_uri

-- Get request headers (excluding hop-by-hop headers)
local request_headers = {}
for key, value in pairs(ngx.req.get_headers()) do
    local lower_key = string.lower(key)
    if lower_key ~= "connection" and lower_key ~= "upgrade" and
       lower_key ~= "proxy-authenticate" and lower_key ~= "proxy-authorization" and
       lower_key ~= "te" and lower_key ~= "trailers" and lower_key ~= "transfer-encoding" then
        request_headers[key] = value
    end
end

-- Add proxy headers
request_headers["X-Real-IP"] = ngx.var.remote_addr
request_headers["X-Forwarded-For"] = ngx.var.proxy_add_x_forwarded_for or ngx.var.remote_addr
request_headers["X-Forwarded-Proto"] = ngx.var.scheme
request_headers["Host"] = backend_host .. ":" .. backend_port

-- Read request body if present
local request_body = nil
if method ~= "GET" and method ~= "HEAD" then
    ngx.req.read_body()
    request_body = ngx.req.get_body_data()
end

-- Make request to backend
local res, err = httpc:request_uri(backend_request_url, {
    method = method,
    headers = request_headers,
    body = request_body,
    ssl_verify = false
})

if not res then
    utils.log("error", "Backend request failed: " .. (err or "unknown error"))
    ngx.status = 502
    ngx.header["Content-Type"] = "application/json"
    ngx.say('{"error": "Backend unavailable"}')
    
    -- Record metrics
    local response_time = ngx.now() - start_time
    metrics.record_request(route_pattern, method, 502, response_time, cache_status)
    return
end

-- Set response headers (excluding hop-by-hop headers)
for key, value in pairs(res.headers) do
    local lower_key = string.lower(key)
    if lower_key ~= "connection" and lower_key ~= "upgrade" and
       lower_key ~= "proxy-authenticate" and lower_key ~= "proxy-authorization" and
       lower_key ~= "te" and lower_key ~= "trailers" and lower_key ~= "transfer-encoding" then
        ngx.header[key] = value
    end
end

-- Add cache status header
ngx.header["X-Cache-Status"] = string.upper(cache_status)
ngx.header["X-Proxy-Server"] = "sembo-cdn"

-- Set status and send response
ngx.status = res.status
ngx.print(res.body)

-- Cache successful GET responses
if method == "GET" and utils.should_cache(method, res.status) then
    local response_data = {
        status = res.status,
        headers = res.headers,
        body = res.body,
        timestamp = ngx.time()
    }
    
    -- Cache with default TTL, could be made configurable per route
    cache.set(cache_key, response_data)
end

-- Record metrics
local response_time = ngx.now() - start_time
metrics.record_request(route_pattern, method, res.status, response_time, cache_status)

utils.log("debug", "Proxied request: " .. method .. " " .. full_uri .. " -> " .. res.status .. " (" .. string.format("%.3f", response_time) .. "s)")
