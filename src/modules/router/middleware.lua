local router = require "modules.router.utils"

--- @class RouterMiddleware: Middleware
--- @field routes_config table
--- @field __index RouterMiddleware
local RouterMiddleware = {}
RouterMiddleware.__index = RouterMiddleware

--- @param routes_config table
--- @return RouterMiddleware
function RouterMiddleware:new(routes_config)
    local instance = setmetatable({}, RouterMiddleware)
    instance.routes_config = routes_config
    return instance
end

--- @param request Request
--- @param next fun(request: Request): Response
--- @return Response
function RouterMiddleware:execute(request, next)
    local route_name = router.get_pattern_from_routes(self.routes_config, request.path)
    
    local response = next(request)
    
    response.locals.route = route_name
    
    return response
end

return RouterMiddleware