-- Initialize Lua modules and shared resources
local metrics = require "modules.metrics"
local utils = require "modules.utils"
local config = require "modules.config"
local cjson = require "cjson"

-- Initialize metrics storage
metrics.init()

utils.debug('Initializing Sembo CDN...')

-- Print configuration during initialization
local full_config = config.get_all()
utils.info("Sembo CDN configuration: " .. cjson.encode(full_config))

-- Log initialization
utils.info("Sembo CDN initialized successfully")
