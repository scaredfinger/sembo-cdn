--- @param request Request
--- @return string
local function cache_key_strategy_host_path(request)
    return "cache:" .. request.host .. ":" .. request.path

end

return cache_key_strategy_host_path