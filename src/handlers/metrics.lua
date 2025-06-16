-- Metrics handler for Prometheus format
local metrics = require "modules.metrics"

-- Set content type for Prometheus
ngx.header["Content-Type"] = "text/plain; version=0.0.4; charset=utf-8"

-- Generate and return Prometheus metrics
local prometheus_output = metrics.generate_prometheus()
ngx.say(prometheus_output)
