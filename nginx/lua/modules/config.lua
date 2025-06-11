-- Configuration management
local _M = {}

-- Default values
local defaults = {
    -- Logging
    log_level = "info",
    
    -- Redis
    redis_host = "127.0.0.1",
    redis_port = 6379,
    redis_timeout = 1000,
    redis_pool_size = 100,
    redis_backlog = 100,
    redis_default_ttl = 300,
    
    -- Backend
    backend_host = "localhost",
    backend_port = 8080,
    
    -- Environment
    env = "production"
}

-- Get environment variable with default
local function get_env(key, default)
    return os.getenv(key) or default
end

-- Expose the get_env function for legacy compatibility
_M.get_env = get_env

-- Initialize configuration
local config = {
    -- Log settings
    log_level = get_env("LOG_LEVEL", defaults.log_level),
    
    -- Redis settings
    redis = {
        host = get_env("REDIS_HOST", defaults.redis_host),
        port = tonumber(get_env("REDIS_PORT", defaults.redis_port)),
        timeout = defaults.redis_timeout,
        pool_size = defaults.redis_pool_size,
        backlog = defaults.redis_backlog,
        default_ttl = defaults.redis_default_ttl
    },
    
    -- Backend settings
    backend = {
        host = get_env("BACKEND_HOST", defaults.backend_host),
        port = tonumber(get_env("BACKEND_PORT", defaults.backend_port)),
        healthcheck_path = get_env("BACKEND_HEALTHCHECK_PATH", "")
    },
    
    -- Environment
    env = get_env("ENV", defaults.env),
    
    -- Log levels mapping (for internal use)
    log_levels = {
        debug = 1,
        info = 2,
        warn = 3,
        error = 4
    }
}

-- Get the current log level value
function _M.get_log_level_value()
    return config.log_levels[config.log_level] or config.log_levels.info
end

-- Get the current log level name
function _M.get_log_level()
    return config.log_level
end

-- Get Redis configuration
function _M.get_redis_config()
    return config.redis
end

-- Get backend configuration
function _M.get_backend_config()
    return config.backend
end

-- Get environment
function _M.get_env()
    return config.env
end

-- Get full configuration (for debugging)
function _M.get_all()
    return config
end

-- Get log levels
function _M.get_log_levels()
    return config.log_levels
end

return _M
