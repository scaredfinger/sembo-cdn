--- @param surrogate_key_header string|nil
--- @return string[]
local function parse_surrogate_key(surrogate_key_header)
    if not surrogate_key_header or surrogate_key_header == "" then
        return {}
    end

    local surrogate_keys = {}
    
    for raw_key in surrogate_key_header:gmatch("[^%s]+") do
        local trimmed_key = raw_key:match("^%s*(.-)%s*$")
        if trimmed_key and trimmed_key ~= "" then
            table.insert(surrogate_keys, trimmed_key)
        end
    end

    return surrogate_keys
end

return parse_surrogate_key
