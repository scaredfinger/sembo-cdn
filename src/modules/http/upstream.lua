local http = require "resty.http"
local Response = require "modules.http.response"

--- @class Upstream: Handler
--- @field __index Upstream
--- @field upstream_url string
local Upstream = {}
Upstream.__index = Upstream

--- @param upstream_url string
--- @return Upstream
function Upstream:new(upstream_url)
    local instance = setmetatable({}, Upstream)
    instance.upstream_url = upstream_url
    return instance
end

--- @param request Request
--- @return Response
function Upstream:execute(request)
    local httpc = http.new()
    httpc:set_timeout(1000)

    local res, err = httpc:request_uri(self.upstream_url, {
        method = request.method,
        path = request.path,
        headers = request.headers,
        body = request.body,
        ssl_verify = false, -- Adjust as necessary for your SSL configuration
    })

    ngx.log(ngx.DEBUG,
        "Upstream request to " ..
        self.upstream_url .. " returned status: " .. (res and res.status or "nil") .. ", error: " .. (err or "nil"))

    if not res or err then
        
        local status = 500
        local body = "Failed to connect to upstream: " .. (err or "unknown error")
        local headers = { ["Content-Type"] = "text/plain" }
        
        return Response:new(status, body, headers)
    end

    if ngx.get_phase() == "timer" then
        httpc:close()
    else
        httpc:set_keepalive()
    end

    local status = res.status
    local body = res.body
    local headers = res.headers
    
    return Response:new(status, body, headers)
end

return Upstream
