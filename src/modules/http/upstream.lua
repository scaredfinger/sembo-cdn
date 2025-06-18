local http = require "resty.http"

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
    local res, err = httpc:request_uri(self.upstream_url, {
        method = request.method,
        path = request.path,
        headers = request.headers,
        body = request.body,
        ssl_verify = false,  -- Adjust as necessary for your SSL configuration
    })

    if not res then
        return {
            status = 500,
            body = "Failed to connect to upstream: " .. (err or "unknown error"),
            headers = { ["Content-Type"] = "text/plain" },
        }
    end

    return {
        status = res.status,
        body = res.body,
        headers = res.headers,
    }
end

return Upstream

