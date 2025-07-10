-- Create metrics instance
local metrics = require "handlers.metrics.instance"

local prometheus_output = metrics:generate_prometheus()
-- Set content type for Prometheus
ngx.header["Content-Type"] = "text/plain; version=0.0.4; charset=utf-8"

--- @type SharedDictionary
local shared_metrics = metrics.metrics_dict
local keys = shared_metrics:get_keys(0)
local capacity = shared_metrics:capacity()
local free_space = shared_metrics:free_space()

ngx.print("# Stats")
ngx.print("\n")
ngx.print('keys: ' .. #keys .. "\n")
ngx.print('capacity: ' .. (capacity / 1024) .. "kb\n")
ngx.print('free_space: ' .. (free_space / 1024) .. "kb\n")
