local routes_config = require "handlers.utils.routes"
--- @type string[]
local route_names = {}
for _, pattern in ipairs(routes_config.patterns) do
  table.insert(route_names, pattern.name)
end
table.insert(route_names, routes_config.fallback)

local metrics = require "utils.metrics.instance"

local metrics_names = require "utils.metrics.names"

metrics:register_histogram(metrics_names.upstream_request, {
  method = { "GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS" },
  cache_state = { "hit", "miss", "stale" },
  route = route_names
}, { 0.1, 0.5, 1, 2, 5, 10, 20, 40, 120 })

metrics:register_histogram(metrics_names.tag_operation, {
  operation = { "get", "set", "delete" }
}, { 0.01, 0.05, 0.1, 0.5, 1, 2 })

metrics:register_histogram(metrics_names.cache_operation, {
  operation = { "get", "set", "delete" },
  cache_name = { "redis", "s3" }
}, { 0.01, 0.05, 0.1, 0.5, 1, 2 })

metrics:register_gauge(metrics_names.shared_dictionary, {
  instance_name = { "metrics", "routes" }
})

return metrics
