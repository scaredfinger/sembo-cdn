local Metrics = require "modules.metrics.index"

local metrics = Metrics.new(
  ngx.shared.metrics,
  function(message)
    ngx.log(ngx.ERR, message)
  end
)
return metrics