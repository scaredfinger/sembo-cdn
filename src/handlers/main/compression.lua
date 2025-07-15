local gzip = require "modules.compression.gzip"
local brotli = require "modules.compression.br"

local CompressionMiddleware = require "modules.compression.middleware"
local instance = CompressionMiddleware:new(
    gzip,
    brotli
)
return instance