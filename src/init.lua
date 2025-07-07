-- Initialize Lua modules and shared resources
local metrics = require "modules.metrics"
local utils = require "modules.utils"
local config = require "modules.config"
local load_patterns_from_file = require "modules.router.utils".load_patterns_from_file
local cjson = require "cjson"

-- Initialize metrics storage
metrics.init()

utils.debug('Initializing Sembo CDN...')

-- Load route patterns from file and store in shared dict
local routes_file = os.getenv("ROUTE_PATTERNS_FILE") or "/usr/local/openresty/nginx/lua/config/route-patterns.json"
local routes_config = load_patterns_from_file(routes_file)

if routes_config then
    local routes_dict = ngx.shared.routes
    if routes_dict then
        local routes_json = cjson.encode(routes_config)
        local ok, err = routes_dict:set("config", routes_json)
        if ok then
            utils.info("Route patterns loaded and stored in shared dictionary")
        else
            utils.error("Failed to store route patterns in shared dictionary: " .. tostring(err))
        end
    else
        utils.error("Routes shared dictionary not available")
    end
else
    utils.error("Failed to load route patterns from file: " .. routes_file)
end

-- Print configuration during initialization
local full_config = config.get_all()
utils.info("Sembo CDN configuration: " .. cjson.encode(full_config))

-- Log initialization
utils.info("Sembo CDN initialized successfully")
