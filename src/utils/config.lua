local log_levels = require "utils.types".log_levels

local defaults = {
    log_level = "info",
    redis_host = "127.0.0.1",
    redis_port = 6379,
    redis_timeout = 1000,
    redis_pool_size = 100,
    redis_backlog = 100,
    redis_default_ttl = 300,
    upstream_host = "localhost",
    upstream_port = 8080,
    env = "production"
}

--- @param key string
--- @param default any
--- @return any
local function get_env(key, default)
    return os.getenv(key) or default
end

local config = {
    --- @type LogLevel
    log_level = get_env("LOG_LEVEL", defaults.log_level),
    redis = {
        host = get_env("REDIS_HOST", defaults.redis_host),
        port = tonumber(get_env("REDIS_PORT", defaults.redis_port)),
        timeout = defaults.redis_timeout,
        pool_size = defaults.redis_pool_size,
        backlog = defaults.redis_backlog,
        default_ttl = defaults.redis_default_ttl
    },
    backend = {
        host = get_env("UPSTREAM_HOST", defaults.upstream_host),
        port = tonumber(get_env("UPSTREAM_PORT", defaults.upstream_port)),
        healthcheck_path = get_env("UPSTREAM_HEALTHCHECK_PATH", "")
    },
    env = get_env("ENV", defaults.env)
}

--- @return LogLevelValue
local function get_log_level_value()
    return log_levels[config.log_level] or config.log_levels.info
end

local function get_log_level()
    return config.log_level
end

local function get_redis_config()
    return config.redis
end

local function get_upstream_config()
    return config.backend
end

--- @return string
local function get_upstream_url()
    local backend = config.backend
    return "http://" .. backend.host .. ":" .. backend.port
end

local function get_all()
    return config
end

local function get_log_levels()
    return config.log_levels
end

return {
    get_log_level_value = get_log_level_value,
    get_log_level = get_log_level,
    get_redis_config = get_redis_config,
    get_upstream_config = get_upstream_config,
    get_upstream_url = get_upstream_url,
    get_all = get_all,
    get_log_levels = get_log_levels
}
