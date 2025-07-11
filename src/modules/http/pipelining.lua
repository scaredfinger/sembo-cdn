--- @param middlewares Middleware[] Array of middleware objects with execute method
--- @param handler Handler
--- @return HandlerFunction
local function create_pipeline(middlewares, handler)
    local function build_chain(index)
        if index > #middlewares then
            return function (request)
                return handler:execute(request)
            end
        end
        
        local current_middleware = middlewares[index]
        local next_function = build_chain(index + 1)
        
        return function(request)
            return current_middleware:execute(request, next_function)
        end
    end
    
    return build_chain(1)
end

return create_pipeline
