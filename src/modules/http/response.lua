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
--- @return Response
function Response:new(status, body, headers)
  return setmetatable({
    status = status,
    body = body,
    headers = headers or {},
    locals = {}
  }, self)
end

return Response
