local MetricsMiddleware = require("modules.metrics.middleware")
local routes_config = require "handlers.utils.routes"

local metrics = require("handlers.utils.metrics.instance")
local metrics_names = require("handlers.utils.metrics.names")

local instance = MetricsMiddleware:new(
    metrics,
    metrics_names.upstream_request,
    ngx.now,
    function (request, response)
        return {
            cache_state = (response and response.locals and response.locals.cache_state) or 'miss',
            method = request.method,
            route = (response and response.locals and response.locals.route) or routes_config.fallback,
        }
    end
)
return instance
