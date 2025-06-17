---@class CacheProvider
---@field __index CacheProvider
local CacheProvider = {}
CacheProvider.__index = CacheProvider

---@return CacheProvider
function CacheProvider:new()
    error("CacheProvider is an abstract class and cannot be instantiated directly")
end

---@param key string
---@return any|nil
function CacheProvider:get(key)
    error("get method must be implemented by concrete cache provider")
end

---@param key string
---@param value any
---@param tts number|nil
---@param ttl number|nil
---@return boolean
function CacheProvider:set(key, value, tts, ttl)
    error("set method must be implemented by concrete cache provider")
end

---@param key string
---@param tag string 
---@return boolean
function CacheProvider:add_key_to_tag(key, tag)
    error("add_to_tags method must be implemented by concrete cache provider")
end

---@param key string
---@param tag string
---@return boolean
function CacheProvider:remove_key_from_tag(tag, key)
    error("del_from_tags method must be implemented by concrete cache provider")
end

---@param key string
---@return boolean
function CacheProvider:del(key)
    error("del method must be implemented by concrete cache provider")
end

---@param tag string 
---@return boolean 
function CacheProvider:del_by_tag(tag)
    error("del_by_tag method must be implemented by concrete cache provider")
end

return CacheProvider
