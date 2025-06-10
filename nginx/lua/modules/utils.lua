-- Utility functions
local config = require "modules.config"
local _M = {}

-- Log level configuration
local LOG_LEVELS = config.get_log_levels()

-- Get current log level
local function get_current_log_level()
    return config.get_log_level_value()
end

-- Individual log functions for each level
function _M.debug(message)
    if LOG_LEVELS.debug >= get_current_log_level() then
        ngx.log(ngx.DEBUG, "[sembo-cdn] ", message)
    end
end

function _M.info(message)
    if LOG_LEVELS.info >= get_current_log_level() then
        ngx.log(ngx.INFO, "[sembo-cdn] ", message)
    end
end

function _M.warn(message)
    if LOG_LEVELS.warn >= get_current_log_level() then
        ngx.log(ngx.WARN, "[sembo-cdn] ", message)
    end
end

function _M.error(message)
    if LOG_LEVELS.error >= get_current_log_level() then
        ngx.log(ngx.ERR, "[sembo-cdn] ", message)
    end
end

-- Legacy support function (deprecated)
function _M.log(level, message)
    if level == "debug" then
        _M.debug(message)
    elseif level == "info" then
        _M.info(message)
    elseif level == "warn" then
        _M.warn(message)
    elseif level == "err" or level == "error" then
        _M.error(message)
    else
        ngx.log(ngx.WARN, "[sembo-cdn] Invalid log level: " .. tostring(level))
    end
end

-- Get environment variable with default (deprecated, use config module instead)
function _M.get_env(key, default)
    ngx.log(ngx.WARN, "[sembo-cdn] utils.get_env is deprecated, use config module instead")
    -- Forward to config module's internal function for backward compatibility
    return require("modules.config").get_env(key, default)
end

-- Generate cache key from request
function _M.generate_cache_key(uri, args)
    local key = "cache:" .. uri
    if args and args ~= "" then
        key = key .. "?" .. args
    end
    return key
end

-- Parse query string into table
function _M.parse_query_string(query_string)
    local params = {}
    if not query_string or query_string == "" then
        return params
    end
    
    for pair in string.gmatch(query_string, "[^&]+") do
        local key, value = string.match(pair, "([^=]+)=([^=]+)")
        if key and value then
            params[ngx.unescape_uri(key)] = ngx.unescape_uri(value)
        end
    end
    
    return params
end

-- Check if request should be cached
function _M.should_cache(method, status)
    -- Only cache GET requests with successful responses
    if method ~= "GET" then
        return false
    end
    
    return status == 200 or status == 301 or status == 302
end

return _M
