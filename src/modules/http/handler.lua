--- @alias HandlerFunc fun(request: Request): Response

--- @class Handler
--- @field __index Handler
local Handler = {}
Handler.__index = Handler

--- @return Handler
function Handler:new()
    local instance = setmetatable({}, Handler)
    return instance
end

--- @param request Request
--- @return Response
function Handler:execute(request)
    -- This method should be overridden by subclasses
    error("execute method not implemented in Handler class")
end

return Handler