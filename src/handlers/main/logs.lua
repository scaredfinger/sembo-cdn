local LogMiddleware = require "modules.logs.middleware"
local NgxLogger = require "modules.logs.index"

local logger = NgxLogger:new()

local instance = LogMiddleware:new(logger)
return instance
