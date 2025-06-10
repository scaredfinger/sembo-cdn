-- Redis-based response caching
local redis = require "resty.redis"
local cjson = require "cjson"
local utils = require "modules.utils"
local config_module = require "modules.config"
local _M = {}

-- Cache configuration
local config = config_module.get_redis_config()

-- Connect to Redis
function _M.connect()
    local red = redis:new()
    red:set_timeout(config.timeout)
    
    local ok, err = red:connect(config.host, config.port)
    if not ok then
        utils.error("Failed to connect to Redis: " .. (err or "unknown error"))
        return nil, err
    end
    
    return red
end

-- Close Redis connection
function _M.close(red)
    if not red then
        return
    end
    
    local ok, err = red:set_keepalive(10000, config.pool_size)
    if not ok then
        utils.warn("Failed to set Redis keepalive: " .. (err or "unknown error"))
        red:close()
    end
end

-- Get cached response
function _M.get(key)
    local red, err = _M.connect()
    if not red then
        return nil, "redis_error"
    end
    
    local cached_data, err = red:get(key)
    _M.close(red)
    
    if not cached_data or cached_data == ngx.null then
        utils.debug("Cache miss for key: " .. key)
        return nil, "miss"
    end
    
    local success, data = pcall(cjson.decode, cached_data)
    if not success then
        utils.error("Failed to decode cached data for key: " .. key)
        return nil, "decode_error"
    end
    
    utils.debug("Cache hit for key: " .. key)
    return data, "hit"
end

-- Store response in cache
function _M.set(key, response_data, ttl)
    ttl = ttl or config.default_ttl
    
    local red, err = _M.connect()
    if not red then
        utils.error("Cannot cache response, Redis unavailable: " .. (err or "unknown"))
        return false
    end
    
    local success, encoded_data = pcall(cjson.encode, response_data)
    if not success then
        utils.error("Failed to encode response data for caching")
        _M.close(red)
        return false
    end
    
    local ok, err = red:setex(key, ttl, encoded_data)
    _M.close(red)
    
    if not ok then
        utils.error("Failed to store in Redis: " .. (err or "unknown error"))
        return false
    end
    
    utils.debug("Cached response for key: " .. key .. " (TTL: " .. ttl .. "s)")
    return true
end

-- Delete cached entry
function _M.delete(key)
    local red, err = _M.connect()
    if not red then
        return false
    end
    
    local ok, err = red:del(key)
    _M.close(red)
    
    if ok then
        utils.debug("Deleted cache entry: " .. key)
        return true
    else
        utils.error("Failed to delete cache entry: " .. (err or "unknown error"))
        return false
    end
end

-- Check if Redis is available
function _M.health_check()
    local red, err = _M.connect()
    if not red then
        return false, err
    end
    
    local pong, err = red:ping()
    _M.close(red)
    
    if pong == "PONG" then
        return true, "healthy"
    else
        return false, err or "unexpected_response"
    end
end

-- Get cache statistics
function _M.get_stats()
    local red, err = _M.connect()
    if not red then
        return { error = err or "connection_failed" }
    end
    
    local info, err = red:info("memory")
    _M.close(red)
    
    if not info then
        return { error = err or "info_failed" }
    end
    
    -- Parse Redis info response
    local stats = {}
    for line in string.gmatch(info, "[^\r\n]+") do
        local key, value = string.match(line, "^([^:]+):(.+)$")
        if key and value then
            stats[key] = value
        end
    end
    
    return {
        used_memory = stats.used_memory,
        used_memory_human = stats.used_memory_human,
        connected = true
    }
end

return _M
