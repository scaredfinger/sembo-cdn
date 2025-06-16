---@class CacheProvider
---@field __index CacheProvider
local CacheProvider = {}
CacheProvider.__index = CacheProvider

---Creates a new CacheProvider instance (abstract class)
---@return CacheProvider
function CacheProvider:new()
    error("CacheProvider is an abstract class and cannot be instantiated directly")
end

---Gets a value from the cache
---@param key string The cache key
---@return any|nil The cached value or nil if not found
function CacheProvider:get(key)
    error("get method must be implemented by concrete cache provider")
end

---Sets a value in the cache
---@param key string The cache key
---@param value any The value to cache
---@param ttl number|nil Optional time-to-live in seconds
---@return boolean Success status
function CacheProvider:set(key, value, ttl)
    error("set method must be implemented by concrete cache provider")
end

---Deletes a key from the cache
---@param key string The cache key to delete
---@return boolean Success status
function CacheProvider:del(key)
    error("del method must be implemented by concrete cache provider")
end

---Checks if a key exists in the cache
---@param key string The cache key to check
---@return boolean True if key exists, false otherwise
function CacheProvider:exists(key)
    error("exists method must be implemented by concrete cache provider")
end

---Clears all cache entries
---@return boolean Success status
function CacheProvider:clear()
    error("clear method must be implemented by concrete cache provider")
end

---Disconnects from the cache
---@return boolean Success status
function CacheProvider:disconnect()
    error("disconnect method must be implemented by concrete cache provider")
end

return CacheProvider
