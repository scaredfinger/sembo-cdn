local Logger = require "modules.logs.base"

--- @class FakeLogger: Logger
local FakeLogger = {}
FakeLogger.__index = FakeLogger

setmetatable(FakeLogger, { __index = Logger })

--- @param correlation_id string|nil
--- @return FakeLogger
function FakeLogger:new(correlation_id)
    local instance = setmetatable({}, FakeLogger)
    instance.correlation_id = correlation_id
    return instance
end

--- @param event LogEvent
function FakeLogger:debug(event)
end

--- @param event LogEvent
function FakeLogger:info(event)
end

--- @param event LogEvent
function FakeLogger:warn(event)
end

--- @param event LogEvent
function FakeLogger:error(event)
end

return FakeLogger
