--- @class Response
--- Represents an HTTP response in the middleware system.
--- @field status integer HTTP status code (e.g., 200, 404)
--- @field body any The response body content
--- @field headers table<string, string> Response headers
--- @field locals table<string, any> Optional local variables for the response
local Response = {}
Response.__index = Response

--- Creates a new Response.
--- @param status integer The HTTP status code
--- @param body any The response body content
--- @param headers? table<string, string> Optional response headers
--- @param locals? table<string, any> Optional local variables for the response
--- @return Response
function Response:new(status, body, headers, locals)
  return setmetatable({
    status = status,
    body = body,
    headers = headers or {},
    locals = locals or {}
  }, self)
end

--- @return Response
function Response:clone()
  local headers_shallow_copy = {}
  for k, v in pairs(self.headers) do
    headers_shallow_copy[k] = v
  end

  local locals_shallow_copy = {}
  for k, v in pairs(self.locals) do
    locals_shallow_copy[k] = v
  end

  return Response:new(
    self.status,
    self.body,
    headers_shallow_copy,
    locals_shallow_copy
  )
end

return Response
