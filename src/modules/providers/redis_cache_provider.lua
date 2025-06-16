local CacheProvider = require("modules.providers.cache_provider")
local json = require("json")

---@class RedisCacheProvider : CacheProvider
---@field redis table The Redis client instance
---@field __index RedisCacheProvider
local RedisCacheProvider = setmetatable({}, {__index = CacheProvider})
RedisCacheProvider.__index = RedisCacheProvider

---Creates a new RedisCacheProvider instance
---@param redis_client table The Redis client instance
---@return RedisCacheProvider
function RedisCacheProvider:new(redis_client)
    local instance = setmetatable({}, RedisCacheProvider)
    instance.redis = redis_client
    return instance
end

---Gets a value from Redis cache
---@param key string The cache key
---@return any|nil The cached value or nil if not found
function RedisCacheProvider:get(key)
    local value = self.redis:get(key)
    if value then
        return json.decode(value)
    end
    return nil
end

---Sets a value in Redis cache
---@param key string The cache key
---@param value any The value to cache
---@param ttl number|nil Optional time-to-live in seconds
---@return boolean Success status
function RedisCacheProvider:set(key, value, ttl)
    local serialized = json.encode(value)
    if ttl then
        return self.redis:setex(key, ttl, serialized)
    else
        return self.redis:set(key, serialized)
    end
end

---Deletes a key from Redis cache
---@param key string The cache key to delete
---@return boolean Success status
function RedisCacheProvider:del(key)
    return self.redis:del(key)
end

---Checks if a key exists in Redis cache
---@param key string The cache key to check
---@return boolean True if key exists, false otherwise
function RedisCacheProvider:exists(key)
    local result = self.redis:exists(key)
    return result == 1
end

---Clears all Redis cache entries
---@return boolean Success status
function RedisCacheProvider:clear()
    return self.redis:flushall()
end

---Disconnects from Redis
---@return boolean Success status
function RedisCacheProvider:disconnect()
    return self.redis:quit()
end

return RedisCacheProvider
