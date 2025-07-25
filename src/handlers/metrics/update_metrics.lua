local metrics = require "handlers.utils.metrics.instance"
local metrics_names = require "handlers.utils.metrics.names"

--- @type SharedDictionary
local shared_metrics = ngx.shared.metrics
local metrics_capacity = shared_metrics:capacity()
local metrics_free_space = shared_metrics:free_space()
metrics:set_gauge(metrics_names.shared_dictionary, metrics_free_space / metrics_capacity * 100, {
  instance_name = "metrics"
})

--- @type SharedDictionary
local shared_routes = ngx.shared.routes
local routes_capacity = shared_routes:capacity()
local routes_free_space = shared_routes:free_space()
metrics:set_gauge(metrics_names.shared_dictionary, routes_free_space / routes_capacity * 100, {
  instance_name = "routes"
})
