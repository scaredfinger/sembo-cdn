-- Metrics handler for Prometheus format
local Metrics = require "modules.metrics.index"

local routes_config = require "handlers.utils.routes"
local route_names = {}
for _, pattern in ipairs(routes_config.patterns) do
  table.insert(route_names, pattern.name)
end

local metrics = Metrics.new(ngx.shared.metrics)
metrics:register_composite("upstream_request", "Upstream request metrics", {
    method={"GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"},
    cache_state={"hit", "miss", "stale"},
    route=route_names
  }, "_seconds", "_total", { 0.1, 0.5, 1, 2, 5, 10, 20, 40, 120 })
metrics:register_composite("tag_operation", "Tag operation metrics", {
    operation={"get", "set", "delete"},
  },
  "_seconds", "_total",
  { 0.01, 0.05, 0.1, 0.5, 1, 2 }
)
metrics:register_composite("cache_operation", "Cache operation metrics", {
  operation={"get", "set", "delete"},
  cache_name={"default", "custom"}
}, "_seconds", "_total",
{ 0.01, 0.05, 0.1, 0.5, 1, 2 })

return metrics
