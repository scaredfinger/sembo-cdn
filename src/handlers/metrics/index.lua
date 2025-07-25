local metrics = require "handlers.utils.metrics.instance"

ngx.header["Content-Type"] = "text/plain; version=0.0.4; charset=utf-8"

require "handlers.metrics.update_metrics"

local prometheus_output = metrics:generate_prometheus()
ngx.print(prometheus_output)
