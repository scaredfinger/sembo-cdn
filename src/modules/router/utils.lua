--- @alias Pattern { name: string, regex: string }

local json = require "cjson"

---@param file_path string
---@return {  patterns: Pattern[], fallback: string }
local function load_patterns_from_file(file_path)
    if not file_path then
        error("No file path provided for route patterns")
    end
    
    local file = io.open(file_path, "r")
    if not file then
        error("Could not open route patterns config file: " .. file_path)
    end
    
    local content = file:read("*all")
    file:close()
    
    local ok, parsed = pcall(json.decode, content)
    if not ok then
        error("Could not parse route patterns config JSON: " .. tostring(parsed))
    end
    
    if not parsed.patterns or type(parsed.patterns) ~= "table" then
        error("Invalid route patterns config: missing or invalid 'patterns' array")
    end
    
    local valid_patterns = {}
    for i, pattern in ipairs(parsed.patterns) do
        if pattern.regex and pattern.name then
            local ok, err = pcall(string.match, "test", pattern.regex)
            if ok then
                table.insert(valid_patterns, {
                    regex = pattern.regex,
                    name = pattern.name
                })
            else
                error("Invalid regex pattern at index " .. i .. ": " .. pattern.regex .. " - " .. tostring(err))
            end
        else
            error("Invalid pattern at index " .. i .. ": missing 'regex' or 'name' field")
        end
    end
    
    local result = {
        patterns = valid_patterns,
        fallback = parsed.fallback or "unknown"
    }
    
    return result
end

---@param routes_config table
---@param uri string
---@return Pattern
local function get_pattern_from_routes(routes_config, uri)
    if not routes_config or not routes_config.patterns then
        error("Invalid routes configuration: missing 'patterns' array")
    end
    
    if not uri then
        error("No URI provided for pattern matching")
    end
    
    for _, route in ipairs(routes_config.patterns) do
        if string.match(uri, route.regex) then
            return route.name
        end
    end

    local fallback = routes_config.fallback
    return fallback
end

return {
    load_patterns_from_file = load_patterns_from_file,
    get_pattern_from_routes = get_pattern_from_routes
}