-- Utility functions
local _M = {}

-- Log function with level support
function _M.log(level, message)
    local log_level = os.getenv("LOG_LEVEL") or "info"
    local levels = {
        debug = 1,
        info = 2,
        warn = 3,
        error = 4
    }
    
    if levels[level] and levels[log_level] and levels[level] >= levels[log_level] then
        ngx.log(ngx[string.upper(level)], "[sembo-cdn] ", message)
    end
end

-- Get environment variable with default
function _M.get_env(key, default)
    return os.getenv(key) or default
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
