local execute_upstream = require "handlers.main.upstream"
local cache = require "handlers.main.cache"
local router = require "handlers.main.router"
local surrogate = require "handlers.main.surrogate"
local metrics = require "handlers.main.metrics"

local function execute(request)
    return metrics:execute(request, function(mir)
        return cache:execute(mir, function(cir)
            return router:execute(cir, function(sir)
                return surrogate:execute(sir, execute_upstream)
            end)
        end)
    end)
end

local http = require "handlers.utils.http"
local incoming_request = http.get_incoming_request()

local cached_or_fresh_response = execute(incoming_request)

http.send_response_to_client(cached_or_fresh_response)
