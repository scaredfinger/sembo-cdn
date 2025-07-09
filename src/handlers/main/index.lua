local cjson = require "cjson"
local config = require "modules.config"

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

local incoming_request = require "handlers.utils.http"
local cached_or_fresh_response = execute(incoming_request)

--- @param response Response
--- @return nil
local function send_response_to_client(response)
    ngx.status = response.status or 200

    for key, value in pairs(response.headers) do
        ngx.header[key] = value
    end

    if (config.get_log_level_value() <= config.get_log_levels().debug) then
        ngx.header['X-DEBUG'] = cjson.encode({
            locals = response.locals
        })
    end

    ngx.print(response.body)
end

send_response_to_client(cached_or_fresh_response)
