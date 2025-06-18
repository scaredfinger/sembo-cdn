local Request = require "modules.http.request"
local Response = require "modules.http.response"

local upstream = require "handlers.main.upstream"
local cache = require "handlers.main.cache"

local method = ngx.var.request_method
local request_headers = ngx.req.get_headers()
local uri = ngx.var.request_uri
local host = request_headers["Host"] or ngx.var.host

-- Read request body if present
local request_body = nil
if method ~= "GET" and method ~= "HEAD" then
    ngx.req.read_body()
    request_body = ngx.req.get_body_data()
end

local request = Request:new(
    method,
    uri,
    request_headers,
    request_body,
    {},
    host,
    os.time()
)

local response = cache:execute(request, function (req)
    return upstream:execute(req)
end)

-- Prepare response
ngx.status = response.status or 200
ngx.header = response.headers or {}
ngx.print(response.body)