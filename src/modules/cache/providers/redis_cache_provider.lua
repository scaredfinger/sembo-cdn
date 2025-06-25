local cjson = require "cjson"

---@class RedisCacheProvider : CacheProvider
---@field redis table
---@field __index RedisCacheProvider
local RedisCacheProvider = {}
RedisCacheProvider.__index = RedisCacheProvider

---@param redis_client table
---@return RedisCacheProvider
function RedisCacheProvider:new(redis_client)
    local instance = setmetatable({}, RedisCacheProvider)
    instance.redis = redis_client
    return instance
end

---@param key string
---@return any|nil
function RedisCacheProvider:get(key)
    local value = self.redis:get(key)
    if value then
        return cjson.decode(value)
    end
    return nil
end

---@param key string
---@param value any
---@param tts number|nil
---@param ttl number|nil
---@return boolean
function RedisCacheProvider:set(key, value, tts, ttl)
    local serialized = cjson.encode(value)
    if ttl then
        return self.redis:setex(key, ttl, serialized)
    else
        return self.redis:set(key, serialized)
    end
end

---@param key string
---@param tag string 
---@return boolean
function RedisCacheProvider:add_key_to_tag(key, tag)
    return self.redis:sadd(tag, key)
end

---@param key string
---@param tag string
---@return boolean
function RedisCacheProvider:remove_key_from_tag(tag, key)
    return self.redis:srem(tag, key)
end

---@param key string
---@return boolean
function RedisCacheProvider:del(key)
    return self.redis:del(key)
end

---@param tag string 
---@return boolean 
function RedisCacheProvider:del_by_tag(tag)
    local keys = self.redis:smembers(tag)
    if keys and #keys > 0 then
        self.redis:del(keys)
    end

    return self.redis:del(tag)
end

---@return boolean
function RedisCacheProvider:health()
    local ok, result = pcall(function()
        return self.redis:ping()
    end)
    return ok and (result == "PONG" or result == true)
end

---@return boolean
function RedisCacheProvider:disconnect()
    return self.redis:quit()
end

return RedisCacheProvider
