-- Metrics handler for Prometheus format
local Metrics = require "modules.metrics.index"
local cjson = require "cjson"

local metrics = Metrics.new(ngx.shared.metrics)

local routes_dict = ngx.shared.routes
local routes_json = routes_dict:get("config")
local routes_config = cjson.decode(routes_json)

metrics:register_histogram("response_time", "Response time histogram", {"method"}, {{ method="GET" }})

return metrics
