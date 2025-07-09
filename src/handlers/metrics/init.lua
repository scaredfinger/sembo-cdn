-- Metrics handler for Prometheus format
local Metrics = require "modules.metrics.index"

local routes_config = require "handlers.utils.routes"
local route_names = {}
for _, pattern in ipairs(routes_config.patterns) do
  table.insert(route_names, pattern.name)
end

local metrics = Metrics.new(ngx.shared.metrics)
metrics:register_histogram("success_upstream_request_seconds", "", {
  method={"GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"},
  cache_state={"hit", "miss", "stale"},
  route=route_names
}, { 0.1, 0.5, 1, 2, 5, 10, 20, 40, 120 })
metrics:register_counter("failed_upstream_request", "", {
  method={"GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"},
  cache_state={"hit", "miss", "stale"},
  route=route_names
})
metrics:register_histogram("success_tag_operation_seconds", "", {
  },
  { 0.01, 0.05, 0.1, 0.5, 1, 2 }
)
metrics:register_counter("failed_tag_operation", "", {
})

return metrics
