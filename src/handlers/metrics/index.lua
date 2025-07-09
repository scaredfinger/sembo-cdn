-- Create metrics instance
local metrics = require "handlers.metrics.instance"

local cjson = require "cjson"
ngx.log(ngx.ERR, "Metrics initialized with composite metrics")
ngx.log(ngx.ERR, "Metrics: ", cjson.encode(ngx.shared.metrics:get_keys()))

-- Set content type for Prometheus
ngx.header["Content-Type"] = "text/plain; version=0.0.4; charset=utf-8"

-- Generate and return Prometheus metrics
local prometheus_output = metrics:generate_prometheus()
ngx.print(prometheus_output)
