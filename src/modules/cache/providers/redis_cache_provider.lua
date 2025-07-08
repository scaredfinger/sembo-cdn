local cjson = require "cjson"

---@class RedisCacheProvider : CacheProvider
---@field open_connection fun(): table
---@field close_connection fun(connection: table): boolean
---@field null_value any
---@field __index RedisCacheProvider
local RedisCacheProvider = {}
RedisCacheProvider.__index = RedisCacheProvider

---@param open_connection fun(): table
---@param close_connection fun(connection: table): boolean
---@param null_value any
---@return RedisCacheProvider
function RedisCacheProvider:new(open_connection, close_connection, null_value)
    local instance = setmetatable({}, RedisCacheProvider)
    instance.open_connection = open_connection
    instance.close_connection = close_connection
    instance.null_value = null_value

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
        self:disconnect()
        return nil
    end
    
    local result = nil
    if value and value ~= self.null_value then
        result = cjson.decode(value)
    end
    
    self:disconnect()
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
    
    self:disconnect()
    return result
end

---@param key string
---@return boolean
function RedisCacheProvider:del(key)
    if not self:connect() then
        return false
    end
    
    local result = self.redis:del(key)
    self:disconnect()
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
    
    self:disconnect()
    return ok and (result == "PONG" or result == true)
end

---@private
---@return boolean
function RedisCacheProvider:connect()
    self.redis = self.open_connection()
    
    return true
end

---@private
---@return boolean
function RedisCacheProvider:disconnect()
    return self.close_connection(self.redis)
end

return RedisCacheProvider
