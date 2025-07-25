
local logs = require "utils.logs"
local config = require "utils.config"
local load_patterns_from_file = require "modules.router.utils".load_patterns_from_file
local cjson = require "cjson"

logs.debug('Initializing Sembo CDN...')


local routes_file = os.getenv("ROUTE_PATTERNS_FILE") or "/usr/local/openresty/nginx/lua/config/route-patterns.json"
local routes_config = load_patterns_from_file(routes_file)

if routes_config then
    local routes_dict = ngx.shared.routes
    if routes_dict then
        local routes_json = cjson.encode(routes_config)
        local ok, err = routes_dict:set("config", routes_json)
        if ok then
            logs.info("Route patterns loaded and stored in shared dictionary")
        else
            logs.error("Failed to store route patterns in shared dictionary: " .. tostring(err))
        end
    else
        logs.error("Routes shared dictionary not available")
    end
else
    logs.error("Failed to load route patterns from file: " .. routes_file)
end

require "handlers.utils.metrics.init"

local full_config = config.get_all()
logs.debug("Sembo CDN configuration: " .. cjson.encode(full_config))

logs.info("Sembo CDN initialized successfully")
