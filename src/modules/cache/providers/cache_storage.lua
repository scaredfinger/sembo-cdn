--- @class CacheStorage
--- @field __index CacheStorage
local CacheStorage = {}
CacheStorage.__index = CacheStorage

--- @return CacheStorage
function CacheStorage:new()
    error("CacheProvider is an abstract class and cannot be instantiated directly")
end

--- @param key string
--- @return string|nil
function CacheStorage:get(key)
    error("get method must be implemented by concrete cache provider")
end

--- @param key string
--- @param value string
--- @param tts number|nil
--- @param ttl number|nil
--- @return boolean
function CacheStorage:set(key, value, tts, ttl)
    error("set method must be implemented by concrete cache provider")
end

--- @param key string
--- @return boolean
function CacheStorage:del(key)
    error("del method must be implemented by concrete cache provider")
end

return CacheStorage
