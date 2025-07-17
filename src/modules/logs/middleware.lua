local event_ids = require "modules.logs.event_ids"

--- @class LogMiddleware: Middleware
--- @field logger Logger
--- @field __index LogMiddleware
local LogMiddleware = {}
LogMiddleware.__index = LogMiddleware

--- @param logger Logger
--- @return LogMiddleware
function LogMiddleware:new(logger)
    local instance = setmetatable({}, LogMiddleware)
    instance.logger = logger
    return instance
end

--- @param request Request
--- @param next fun(request: Request): Response A function to call the next middleware or handler
function LogMiddleware:execute(request, next)
    self.logger:debug({
        event_id = event_ids.LOG_MIDDLEWARE_REQUEST_STARTED_DEBUG,
        request = request
    })

    local success, response = pcall(next, request)

    if not success then
        self.logger:error({
            event_id = event_ids.LOG_MIDDLEWARE_REQUEST_ERROR,
            request = request,
            error = response
        })
        error(response)
    end

    self.logger:debug({
        event_id = event_ids.LOG_MIDDLEWARE_REQUEST_FINISHED_DEBUG,
        request = request,
        response = response
    })

    return response
end

return LogMiddleware
