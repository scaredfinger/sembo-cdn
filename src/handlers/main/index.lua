local execute_upstream = require "handlers.main.upstream"
local cache = require "handlers.main.cache"
local surrogate = require "handlers.main.surrogate"
local router = require "handlers.main.router"

local function execute(request)
    return cache:execute(request, function (cir)
        return router:execute(cir, function (sir)
            return surrogate:execute(sir, execute_upstream)
        end)
    end)
end

local http = require "handlers.utils.http"
local incoming_request = http.get_incoming_request()
local send_response_to_client = http.send_response_to_client

local cached_or_fresh_response = execute(incoming_request)

send_response_to_client(cached_or_fresh_response)
