local Request = require "modules.http.request"

--- @return string, table, string, string, number
local function extract_request_metadata()
    local http_method = ngx.var.request_method
    local request_headers = ngx.req.get_headers()
    local request_uri = ngx.var.request_uri
    local request_host = request_headers["Host"] or ngx.var.host
    local current_timestamp = os.time()

    return http_method, request_headers, request_uri, request_host, current_timestamp
end

--- @param method string
--- @return boolean
local function should_read_request_body(method)
    return method ~= "GET" and method ~= "HEAD"
end

--- @param method string
--- @return string|nil
local function get_request_body_if_needed(method)
    if not should_read_request_body(method) then
        return nil
    end

    ngx.req.read_body()
    return ngx.req.get_body_data()
end

local http_method, request_headers, request_uri, request_host, current_timestamp = extract_request_metadata()
local request_body = get_request_body_if_needed(http_method)

local incoming_request = Request:new(
    http_method,
    request_uri,
    request_headers,
    request_body,
    {},
    request_host,
    current_timestamp
)

local execute_upstream = require "handlers.main.upstream"
local cache = require "handlers.main.cache"

local function execute(request)
    return cache:execute(request, execute_upstream)
end

local cached_or_fresh_response = execute(incoming_request)

--- @param response Response
--- @return nil
local function send_response_to_client(response)
    ngx.status = response.status or 200

    for key, value in pairs(response.headers) do
        ngx.header[key] = value
    end

    ngx.print(response.body)
end

send_response_to_client(cached_or_fresh_response)
