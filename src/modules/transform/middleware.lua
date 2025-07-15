local Middleware = require "modules.http.middleware"
local Request = require "modules.http.request"

--- @class TransformMiddleware: Middleware
--- @field transform_fn fun(request: Request): Request
--- @field __index TransformMiddleware
local TransformMiddleware = {}
TransformMiddleware.__index = TransformMiddleware
setmetatable(TransformMiddleware, {__index = Middleware})

--- @param transform_fn fun(request: Request): Request
--- @return TransformMiddleware
function TransformMiddleware:new(transform_fn)
    local instance = setmetatable({}, TransformMiddleware)
    instance.transform_fn = transform_fn
    return instance
end

--- @param request Request
--- @param next HandlerFunction
--- @return Response
function TransformMiddleware:execute(request, next)
    local cloned_request = request:clone()
    
    local transformed_request = self.transform_fn(cloned_request)
    
    return next(transformed_request)
end

return TransformMiddleware
