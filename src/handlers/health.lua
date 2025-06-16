-- Health check handler
local cache = require "modules.cache"
local cjson = require "cjson"
local config = require "modules.config"
local http = require "resty.http"

-- Set content type
ngx.header["Content-Type"] = "application/json"

-- Check Redis health
local redis_healthy, redis_status = cache.health_check()

-- Check backend health
local backend_config = config.get_backend_config()
local backend_host = backend_config.host
local backend_port = backend_config.port
local backend_healthy = true
local backend_status = "No health check configured"

-- Perform actual backend health check if healthcheck_path is defined
if backend_config.healthcheck_path and backend_config.healthcheck_path ~= "" then
    local httpc = http.new()
    local backend_url = "http://" .. backend_host .. ":" .. backend_port .. backend_config.healthcheck_path
    
    local res, err = httpc:request_uri(backend_url, {
        method = "GET",
        headers = {
            ["User-Agent"] = "Sembo-CDN-HealthCheck/1.0"
        },
        keepalive_timeout = 2000 -- 2 seconds
    })
    
    if not res then
        backend_healthy = false
        backend_status = "Error connecting to backend: " .. (err or "unknown error")
    else
        -- Consider 2xx status codes as healthy
        backend_healthy = res.status >= 200 and res.status < 300
        backend_status = "Status code: " .. res.status
    end
else
    backend_status = "Assumed healthy (no healthcheck path configured)"
end

-- Overall health status
local overall_healthy = redis_healthy and backend_healthy

-- Response data
local health_data = {
    status = overall_healthy and "healthy" or "unhealthy",
    timestamp = ngx.time(),
    version = "1.0.0",
    services = {
        redis = {
            status = redis_healthy and "healthy" or "unhealthy",
            message = redis_status
        },
        backend = {
            status = backend_healthy and "healthy" or "unhealthy",
            endpoint = backend_host .. ":" .. backend_port,
            message = backend_status
        }
    },
    cache_stats = cache.get_stats()
}

-- Set appropriate HTTP status
if overall_healthy then
    ngx.status = 200
else
    ngx.status = 503
end

-- Return JSON response
ngx.say(cjson.encode(health_data))
