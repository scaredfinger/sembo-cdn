local upstream = require "handlers.main.upstream"

local create_pipeline = require "modules.http.pipelining"

local metrics = require "handlers.main.metrics"
local compression = require "handlers.main.compression"
local cache = require "handlers.main.cache"
local router = require "handlers.main.router"
local surrogate = require "handlers.main.surrogate"

local execute = create_pipeline({
    metrics,
    compression,
    cache,
    -- compressBeforeCaching,
    router,
    surrogate,
}, upstream)

local http = require "handlers.utils.http"
local incoming_request = http.get_incoming_request()

local cached_or_fresh_response = execute(incoming_request)

http.send_response_to_client(cached_or_fresh_response)
