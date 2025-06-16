---@class CacheManager
---@field provider CacheProvider The cache provider instance
---@field __index CacheManager
local CacheManager = {}
CacheManager.__index = CacheManager

---Creates a new CacheManager instance
---@param provider CacheProvider The cache provider to use
---@return CacheManager
function CacheManager:new(provider)
    local instance = setmetatable({}, CacheManager)
    instance.provider = provider
    return instance
end

---Gets a value from the cache
---@param key string The cache key
---@return any|nil The cached value or nil if not found
function CacheManager:get(key)
    return self.provider:get(key)
end

---Sets a value in the cache
---@param key string The cache key
---@param value any The value to cache
---@param ttl number|nil Optional time-to-live in seconds
---@return boolean Success status
function CacheManager:set(key, value, ttl)
    return self.provider:set(key, value, ttl)
end

---Deletes a key from the cache
---@param key string The cache key to delete
---@return boolean Success status
function CacheManager:del(key)
    return self.provider:del(key)
end

---Checks if a key exists in the cache
---@param key string The cache key to check
---@return boolean True if key exists, false otherwise
function CacheManager:exists(key)
    return self.provider:exists(key)
end

---Clears all cache entries
---@return boolean Success status
function CacheManager:clear()
    return self.provider:clear()
end

---Disconnects from the cache
---@return boolean Success status
function CacheManager:disconnect()
    return self.provider:disconnect()
end

return CacheManager
