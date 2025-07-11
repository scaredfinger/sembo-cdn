local cjson = require "cjson"
local config = require "utils.config"
local http = require "resty.http"
local redis = require("resty.redis")

ngx.header["Content-Type"] = "application/json"

local redis_client = redis:new()
local redis_config = config.get_redis_config()
redis_client:set_timeout(redis_config.timeout)
local connection_established, connection_error = redis_client:connect(redis_config.host, redis_config.port)

local redis_healthy = false
local redis_status = "Unknown"
local redis_stats = {}

if connection_established then
    local ping_result, ping_error = redis_client:ping()
    if ping_result == "PONG" then
        redis_healthy = true
        redis_status = "Connected and responsive"
        
        local info_result, info_error = redis_client:info("memory")
        if info_result then
            local used_memory = info_result:match("used_memory:(%d+)")
            local used_memory_human = info_result:match("used_memory_human:([%w%.]+)")
            local maxmemory = info_result:match("maxmemory:(%d+)")
            
            redis_stats = {
                used_memory_bytes = tonumber(used_memory) or 0,
                used_memory_human = used_memory_human or "unknown",
                max_memory_bytes = tonumber(maxmemory) or 0,
                connected = true
            }
        end
    else
        redis_status = "Connected but not responsive: " .. (ping_error or "ping failed")
        redis_stats = { connected = false, error = ping_error or "ping failed" }
    end
    redis_client:close()
else
    redis_status = "Connection failed: " .. (connection_error or "unknown error")
    redis_stats = { connected = false, error = connection_error or "unknown error" }
end

local backend_config = config.get_backend_config()
local backend_host = backend_config.host
local backend_port = backend_config.port
local backend_healthy = true
local backend_status = "No health check configured"

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
        backend_healthy = res.status >= 200 and res.status < 300
        backend_status = "Status code: " .. res.status
    end
else
    backend_status = "Assumed healthy (no healthcheck path configured)"
end

local overall_healthy = redis_healthy and backend_healthy

local health_data = {
    status = overall_healthy and "healthy" or "unhealthy",
    timestamp = ngx.time(),
    version = "1.0.0",
    services = {
        redis = {
            status = redis_healthy and "healthy" or "unhealthy",
            message = redis_status,
            endpoint = redis_config.host .. ":" .. redis_config.port,
            timeout_ms = redis_config.timeout,
            stats = redis_stats
        },
        backend = {
            status = backend_healthy and "healthy" or "unhealthy",
            endpoint = backend_host .. ":" .. backend_port,
            message = backend_status,
            health_check = {
                enabled = backend_config.healthcheck_path and backend_config.healthcheck_path ~= "",
                path = backend_config.healthcheck_path or "not configured"
            }
        }
    }
}

if overall_healthy then
    ngx.status = 200
    ngx.say(cjson.encode(health_data))
else
    ngx.status = 503
end
