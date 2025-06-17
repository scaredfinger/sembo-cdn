---@class ParsedCacheControl
---@field no_cache boolean
---@field no_store boolean
---@field max_age number
---@field private boolean
---@field public boolean
---@field stale_while_revalidate number
---@field surrogate_key string[]

---@class CacheControlParser
---@field __index CacheControlParser
CacheControlParser = {}
CacheControlParser.__index = CacheControlParser

--- @param cache_control_header string
--- @return ParsedCacheControl
function CacheControlParser:parse(cache_control_header)
    ---@type { [string]: string }
    local directives = {}
    for directive in cache_control_header:gmatch("([^,]+)") do
        local key, value = directive:match("^%s*([%w-_]+)%s*=?%s*(.*)")
        if key then
            local lowered_key = key:lower()
            local normalized_key = lowered_key:gsub("[-_]", "_")
            
            local sanitized_value = value and value:match("^%s*(.-)%s*$") or nil

            directives[normalized_key] = sanitized_value
        end
    end

    ---@type ParsedCacheControl
    local result = {
        no_cache = false,
        no_store = false,
        max_age = 0,
        private = false,
        public = false,
        stale_while_revalidate = 0,
        surrogate_key = {},
    }

    result.no_cache = (directives.no_cache and true) or false
    result.no_store = (directives.no_store and true) or false
    result.private = (directives.private and true) or false
    result.public = (directives.public and true) or false
    
    result.max_age = tonumber(directives.max_age) or 0
    result.stale_while_revalidate = tonumber(directives.stale_while_revalidate) or 0
    
    if directives.surrogate_key then
        for key in directives.surrogate_key:gmatch("[^%s]+")
        do
            table.insert(result.surrogate_key, key)
        end
    end

    return result
end

return CacheControlParser
