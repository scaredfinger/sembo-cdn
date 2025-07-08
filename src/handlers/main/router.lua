local RouterMiddleware = require "modules.router.middleware"
local cjson = require "cjson"

local routes_dict = ngx.shared.routes
local routes_json = routes_dict:get("config")
local routes_config = cjson.decode(routes_json)

-- ngx.log(ngx.ERR, "Routes config: ", routes_config)

return RouterMiddleware:new(routes_config)