--- @class MetricsMiddleware: Middleware
--- @field metrics Metrics
--- @field metric_name string
--- @field now fun(): number
--- @field get_labels fun(request: Request, response: Response): table<string, string>
--- @field __index MetricsMiddleware
local MetricsMiddleware = {}
MetricsMiddleware.__index = MetricsMiddleware

--- @param metrics Metrics
--- @param metric_name string
--- @param now fun(): number
--- @param get_labels fun(request: Request, response: Response): table<string, string>
--- @return MetricsMiddleware
function MetricsMiddleware:new(metrics, metric_name, now, get_labels)
    local instance = setmetatable({}, MetricsMiddleware)
    instance.metrics = metrics
    instance.metric_name = metric_name
    instance.now = now
    instance.get_labels = get_labels
    return instance
end

--- @param request Request
--- @param next fun(request: Request): Response
--- @return Response
function MetricsMiddleware:execute(request, next)
    local start_time = self.now()
    
    local success, response = pcall(next, request)
    
    local duration = self.now() - start_time
    local labels = self.get_labels(request, response)

    if success then
        if response.status >= 200 and response.status < 300 then
          self.metrics:observe_composite_success(self.metric_name, duration, labels)
        else
          self.metrics:inc_composite_failure(self.metric_name, 1, labels)
        end
        return response
    else
        self.metrics:inc_composite_failure(self.metric_name, 1, labels)
        error(response)
    end
end

return MetricsMiddleware
