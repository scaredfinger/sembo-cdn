local log_levels = require "utils.types".log_levels
local config = require "utils.config"

local function get_current_log_level()
    return config.get_log_level_value()
end

-- Individual log functions for each level
local function debug(message)
    if log_levels.debug >= get_current_log_level() then
        ngx.log(ngx.DEBUG, "[sembo-cdn] ", message)
    end
end

local function info(message)
    if log_levels.info >= get_current_log_level() then
        ngx.log(ngx.INFO, "[sembo-cdn] ", message)
    end
end

local function warn(message)
    if log_levels.warn >= get_current_log_level() then
        ngx.log(ngx.WARN, "[sembo-cdn] ", message)
    end
end

local function error(message)
    if log_levels.error >= get_current_log_level() then
        ngx.log(ngx.ERR, "[sembo-cdn] ", message)
    end
end

--- @param level LogLevel
--- @param fn function
local function execute_with_log_level(level, fn)
    if log_levels[level] >= get_current_log_level() then
        fn()
    end
end

return {
    debug = debug,
    info = info,
    warn = warn,
    error = error,
    get_current_log_level = get_current_log_level,
    execute_with_log_level = execute_with_log_level
}
