--- @class Middleware
--- @field __index Middleware
local Middleware = {}
Middleware.__index = Middleware

--- @param request Request
--- @param next HandlerFunction
--- @return Response
function Middleware:execute(request, next)
    -- This method should be overridden by subclasses
    error("execute method not implemented in Middleware class")
end

return Middleware