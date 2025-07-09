local Metrics = require "modules.metrics.index"

local metrics = Metrics.new(ngx.shared.metrics)
return metrics