--- @alias LogEvent { event_id: number, [string]: any }

--- @class Logger
--- @field correlation_id string|nil
--- @field __index Logger
local Logger = {}
Logger.__index = Logger

--- @param correlation_id string|nil
--- @return Logger
function Logger:new(correlation_id)
    local instance = setmetatable({}, Logger)
    instance.correlation_id = correlation_id
    return instance
end

--- @param event LogEvent
function Logger:debug(event)
    error("debug method not implemented in Logger class")
end

--- @param event LogEvent
function Logger:info(event)
    error("info method not implemented in Logger class")
end

--- @param event LogEvent
function Logger:warn(event)
    error("warn method not implemented in Logger class")
end

--- @param event LogEvent
function Logger:error(event)
    error("error method not implemented in Logger class")
end

return Logger
