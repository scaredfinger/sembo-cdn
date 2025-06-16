-- Route pattern matching for metrics
local utils = require "modules.utils"
local _M = {}

-- Route patterns configuration
local patterns = {
    {
        pattern = "^/hotels/([^/]+)$",
        name = "hotels/[name]"
    },
    {
        pattern = "^/hotels/([^/]+)/rooms$",
        name = "hotels/[name]/rooms"
    },
    {
        pattern = "^/hotels/([^/]+)/rooms/([^/]+)$",
        name = "hotels/[name]/rooms/[id]"
    },
    {
        pattern = "^/api/v(%d+)/",
        name = "api/v[version]"
    },
    {
        pattern = "^/users/([^/]+)$",
        name = "users/[id]"
    },
    {
        pattern = "^/search%?",
        name = "search"
    }
}

-- Get route pattern for a given URI
function _M.get_pattern(uri)
    if not uri then
        return "default"
    end
    
    -- Check each pattern
    for _, route in ipairs(patterns) do
        if string.match(uri, route.pattern) then
            utils.debug("Matched pattern: " .. route.name .. " for URI: " .. uri)
            return route.name
        end
    end

    -- Return the URI as-is if no pattern matches (truncated for privacy)
        
    utils.debug("No pattern matched for URI: " .. uri .. ", using: " .. uri)
    return "default"
end

-- Add new pattern (for dynamic configuration in future)
function _M.add_pattern(pattern, name)
    table.insert(patterns, {
        pattern = pattern,
        name = name
    })
    utils.info("Added new route pattern: " .. name)
end

-- Get all patterns (for debugging)
function _M.get_all_patterns()
    return patterns
end

return _M
