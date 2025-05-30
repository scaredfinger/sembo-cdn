-- Initialize Lua modules and shared resources
local metrics = require "modules.metrics"
local utils = require "modules.utils"

-- Initialize metrics storage
metrics.init()

-- Log initialization
utils.log("info", "Sembo CDN initialized successfully")
