local cjson = require "cjson"

---@class RedisCacheProvider : CacheProvider
---@field open_connection fun(): table
---@field close_connection fun(connection: table): boolean
---@field __index RedisCacheProvider
local RedisCacheProvider = {}
RedisCacheProvider.__index = RedisCacheProvider

---@param open_connection fun(): table
---@param close_connection fun(connection: table): boolean
---@return RedisCacheProvider
function RedisCacheProvider:new(open_connection, close_connection)
    local instance = setmetatable({}, RedisCacheProvider)
    instance.open_connection = open_connection
    instance.close_connection = close_connection

    return instance
end

---@param key string
---@return any|nil
function RedisCacheProvider:get(key)
    if not self:connect() then
        return nil
    end
    
    local value, err = self.redis:get(key)
    if err then
        self:close_connection()
        return nil
    end
    
    local result = nil
    if value then
        result = cjson.decode(value)
    end
    
    self:close_connection()
    return result
end

---@param key string
---@param value any
---@param tts number|nil
---@param ttl number|nil
---@return boolean
function RedisCacheProvider:set(key, value, tts, ttl)
    if not self:connect() then
        return false
    end
    
    local serialized = cjson.encode(value)
    local result
    if ttl then
        result = self.redis:setex(key, ttl, serialized)
    else
        result = self.redis:set(key, serialized)
    end
    
    self:close_connection()
    return result
end

---@param key string
---@param tag string 
---@return boolean
function RedisCacheProvider:add_key_to_tag(key, tag)
    if not self:connect() then
        return false
    end
    
    local result = self.redis:sadd(tag, key)
    self:close_connection()
    return result
end

---@param key string
---@param tag string
---@return boolean
function RedisCacheProvider:remove_key_from_tag(tag, key)
    if not self:connect() then
        return false
    end
    
    local result = self.redis:srem(tag, key)
    self:close_connection()
    return result
end

---@param key string
---@return boolean
function RedisCacheProvider:del(key)
    if not self:connect() then
        return false
    end
    
    local result = self.redis:del(key)
    self:close_connection()
    return result
end

---@param tag string 
---@return boolean 
function RedisCacheProvider:del_by_tag(tag)
    if not self:connect() then
        return false
    end
    
    local keys = self.redis:smembers(tag)
    if keys and #keys > 0 then
        self.redis:del(keys)
    end

    local result = self.redis:del(tag)
    self:close_connection()
    return result
end

---@return boolean
function RedisCacheProvider:health()
    if not self:connect() then
        return false
    end
    
    local ok, result = pcall(function()
        return self.redis:ping()
    end)
    
    self:close_connection()
    return ok and (result == "PONG" or result == true)
end

---@return boolean
function RedisCacheProvider:connect()
    self.redis = self.open_connection()

    return true
end

---@return boolean
function RedisCacheProvider:close_connection()
    return self.close_connection(self.redis)
end

return RedisCacheProvider
