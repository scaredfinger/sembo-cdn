local cjson = require "cjson"

local routes_dict = ngx.shared.routes
local routes_json = routes_dict:get("config")

--- @type RoutesConfig
local routes_config = cjson.decode(routes_json)

return routes_config