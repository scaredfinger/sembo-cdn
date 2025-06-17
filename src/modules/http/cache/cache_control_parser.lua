---@class CacheControlParser
---@field __index CacheControlParser
CacheControlParser = {}
CacheControlParser.__index = CacheControlParser

--- @param cache_control_header string The Cache-Control header value
--- @return table A table containing parsed directives
function CacheControlParser:parse(cache_control_header)
    local directives = setmetatable({
        ---@type boolean
        no_cache = false,
        ---@type boolean
        no_store = false,
        ---@type number
        max_age = 0,
        ---@type boolean
        private = false,
        ---@type boolean
        public = false,
        ---@type number
        stale_while_revalidate = 0,
        ---@type string[]
        surrogate_key = {},
    }, { __index = function(_, key) return nil end
    })
    for directive in cache_control_header:gmatch("([^,]+)") do
        local key, value = directive:match("(%w+)=?(.*)")
        if key then
            key = key:lower()
            value = value and value:match("^%s*(.-)%s*$") or nil
            directives[key] = value or true
        end
    end
    return directives
end

return CacheControlParser
