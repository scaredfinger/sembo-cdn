-- Health check handler
local cache = require "modules.cache"
local cjson = require "cjson"
local config = require "modules.config"

-- Set content type
ngx.header["Content-Type"] = "application/json"

-- Check Redis health
local redis_healthy, redis_status = cache.health_check()

-- Check backend health (simplified)
local backend_config = config.get_backend_config()
local backend_host = backend_config.host
local backend_port = backend_config.port
local backend_healthy = true -- Could implement actual backend health check

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
            endpoint = backend_host .. ":" .. backend_port
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
