--- @class Request
--- Represents an HTTP request in the middleware system.
--- @field method string The HTTP method (e.g., "GET", "POST")
--- @field path string The request path (e.g., "/users")
--- @field headers table<string, string> The request headers
--- @field body any The request body (parsed, e.g., JSON), can be nil
--- @field query table<string, string> Query string parameters
--- @field host string The value of the Host header
--- @field timestamp number

local Request = {}
Request.__index = Request

--- Creates a new Request.
--- @param method string The HTTP method
--- @param path string The request path
--- @param headers table<string, string> The request headers
--- @param body? any Optional request body
--- @param query? table<string, string> Optional query parameters
--- @param host? string Optional host value
--- @param timestamp? number Optional timestamp (default is current time)
--- @return Request
function Request:new(method, path, headers, body, query, host, timestamp)
  return setmetatable({
    method = method,
    path = path,
    headers = headers or {},
    body = body,
    query = query or {},
    host = host or "",
    timestamp = timestamp or os.time(),
  }, self)
end

--- Gets a request header.
--- @param name string
--- @return string|nil
function Request:get_header(name)
  return self.headers[name]
end

--- Gets a query parameter.
--- @param name string
--- @return string|nil
function Request:get_query(name)
  return self.query[name]
end

--- Gets the host.
--- @return string
function Request:get_host()
  return self.host
end

return Request
