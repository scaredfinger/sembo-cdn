local RouterMiddleware = require "modules.router.middleware"

local routes_config = require "handlers.utils.routes"

return RouterMiddleware:new(routes_config)