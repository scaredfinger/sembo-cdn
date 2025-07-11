local routes_config = require "handlers.utils.routes"
--- @type string[]
local route_names = {}
for _, pattern in ipairs(routes_config.patterns) do
  table.insert(route_names, pattern.name)
end
table.insert(route_names, routes_config.fallback)

local metrics = require "handlers.metrics.instance"

local metrics_names = require "handlers.metrics.names"

metrics:register_composite({
  name = metrics_names.upstream_request,
  label_values = {
    method = { "GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS" },
    cache_state = { "hit", "miss", "stale" },
    route = route_names
  },
  histogram_suffix = "_seconds",
  counter_suffix = "_total",
  buckets = { 0.1, 0.5, 1, 2, 5, 10, 20, 40, 120 }
})

metrics:register_composite({
  name = metrics_names.tag_operation,
  label_values = {
    operation = { "get", "set", "delete" }
  },
  histogram_suffix = "_seconds",
  counter_suffix = "_total",
  buckets = { 0.01, 0.05, 0.1, 0.5, 1, 2 }
})

metrics:register_composite({
  name = metrics_names.cache_operation,
  label_values = {
    operation = { "get", "set", "delete" },
    cache_name = { "redis", "s3" }
  },
  histogram_suffix = "_seconds",
  counter_suffix = "_total",
  buckets = { 0.01, 0.05, 0.1, 0.5, 1, 2 }
})

return metrics
