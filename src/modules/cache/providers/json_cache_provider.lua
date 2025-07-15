local cjson = require "cjson"
local CacheProvider = require "modules.cache.providers.cache_provider"

--- @class JsonCacheProvider : CacheProvider
--- @field storage CacheStorage
--- @field __index JsonCacheProvider
local JsonCacheProvider = {}
JsonCacheProvider.__index = JsonCacheProvider
setmetatable(JsonCacheProvider, {__index = CacheProvider})

--- @param storage CacheStorage
--- @return JsonCacheProvider
function JsonCacheProvider:new(storage)
    local instance = setmetatable({}, JsonCacheProvider)
    instance.storage = storage
    return instance
end

--- @param key string
--- @return any|nil
function JsonCacheProvider:get(key)
    local value = self.storage:get(key)
    if not value then
        return nil
    end
    
    local ok, result = pcall(cjson.decode, value)
    if not ok then
        return nil
    end
    
    return result
end

--- @param key string
--- @param value any
--- @param tts number|nil
--- @param ttl number|nil
--- @return boolean
function JsonCacheProvider:set(key, value, tts, ttl)
    local ok, serialized = pcall(cjson.encode, value)
    if not ok then
        return false
    end
    
    return self.storage:set(key, serialized, tts, ttl)
end

--- @param key string
--- @return boolean
function JsonCacheProvider:del(key)
    return self.storage:del(key)
end

return JsonCacheProvider