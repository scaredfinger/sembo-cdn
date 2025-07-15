local TransformMiddleware = require "modules.transform.middleware"

local compressBeforeCaching = TransformMiddleware:new(function(request)
    request.headers["Accept-Encoding"] = "br"
    return request
end)
return compressBeforeCaching