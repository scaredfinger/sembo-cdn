--- @alias HttpMethod '"GET"' | '"POST"' | '"PUT"' | '"DELETE"' | '"PATCH"' | '"HEAD"' | '"OPTIONS"'
--- @alias HttpStatus integer

--- @class Context
local Context = {}
Context.__index = Context

--- Creates a new abstract Context instance.
--- @return Context
function Context:new()
  local instance = {}
  setmetatable(instance, self)
  return instance
end

--- @return HttpMethod
function Context:get_method()
  error("get_method not implemented")
end

--- Returns the value of a request header.
--- @param name string
--- @return string|nil
function Context:get_header(name)
  error("get_header not implemented")
end

--- Sets a response header.
--- @param name string
--- @param value string
function Context:set_header(name, value)
  error("set_header not implemented")
end

--- Sets the response status code.
--- @param code integer
function Context:set_status(code)
  error("set_status not implemented")
end

--- Sets the response body content.
--- @param data string
function Context:set_result(data)
  error("set_result not implemented")
end

--- Sends the response.
function Context:send()
  error("send not implemented")
end

--- Logs a message.
--- @param level integer
--- @param msg string
function Context:log(level, msg)
  error("log not implemented")
end

return Context
