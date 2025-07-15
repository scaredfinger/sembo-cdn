local gzip = require "modules.compression.gzip"
local brotli = require "modules.compression.br"
local deflate = require "modules.compression.deflate"

local CompressionMiddleware = require "modules.compression.middleware"
local instance = CompressionMiddleware:new(
    gzip,
    brotli,
    deflate
)
return instance