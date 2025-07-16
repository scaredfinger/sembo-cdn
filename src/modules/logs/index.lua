local Logger = require "modules.logs.base"
local log_levels = require "utils.types".log_levels
local config = require "utils.config"
local cjson = require "cjson"

--- @class NgxLogger: Logger
--- @field __index NgxLogger
local NgxLogger = {}
NgxLogger.__index = NgxLogger
setmetatable(NgxLogger, {__index = Logger})

--- @param correlation_id string|nil
--- @return NgxLogger
function NgxLogger:new(correlation_id)
    local instance = setmetatable({}, NgxLogger)
    instance.correlation_id = correlation_id or NgxLogger._generate_correlation_id()
    return instance
end

--- @private
--- @return string
function NgxLogger._generate_correlation_id()
    local random_part = string.format("%08x", math.random(0, 0xFFFFFFFF))
    local timestamp_part = string.format("%x", ngx.now() * 1000)
    return timestamp_part .. "-" .. random_part
end

--- @private
--- @param event LogEvent
--- @return string
function NgxLogger:_format_event(event)
    local log_entry = {
        event_id = event.event_id,
        correlation_id = self.correlation_id,
        timestamp = ngx.now(),
        worker_pid = ngx.worker.pid()
    }
    
    for key, value in pairs(event) do
        if key ~= "event_id" then
            log_entry[key] = value
        end
    end
    
    return cjson.encode(log_entry)
end

--- @private
--- @return number
function NgxLogger:_get_current_log_level()
    return config.get_log_level_value()
end

--- @param event LogEvent
function NgxLogger:debug(event)
    if log_levels.debug >= self:_get_current_log_level() then
        ngx.log(ngx.DEBUG, "[sembo-cdn] ", self:_format_event(event))
    end
end

--- @param event LogEvent
function NgxLogger:info(event)
    if log_levels.info >= self:_get_current_log_level() then
        ngx.log(ngx.INFO, "[sembo-cdn] ", self:_format_event(event))
    end
end

--- @param event LogEvent
function NgxLogger:warn(event)
    if log_levels.warn >= self:_get_current_log_level() then
        ngx.log(ngx.WARN, "[sembo-cdn] ", self:_format_event(event))
    end
end

--- @param event LogEvent
function NgxLogger:error(event)
    if log_levels.error >= self:_get_current_log_level() then
        ngx.log(ngx.ERR, "[sembo-cdn] ", self:_format_event(event))
    end
end

return NgxLogger
