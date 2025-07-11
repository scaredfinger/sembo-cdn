local metrics = require "handlers.metrics.instance"

ngx.header["Content-Type"] = "text/plain; version=0.0.4; charset=utf-8"

local prometheus_output = metrics:generate_prometheus()
ngx.print(prometheus_output)
