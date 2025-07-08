---@class RedisTagsProvider : TagsProvider
---@field open_connection fun(): table
---@field close_connection fun(connection: table): boolean
---@field __index RedisTagsProvider
local RedisTagsProvider = {}
RedisTagsProvider.__index = RedisTagsProvider

---@param open_connection fun(): table
---@param close_connection fun(connection: table): boolean
---@return RedisTagsProvider
function RedisTagsProvider:new(open_connection, close_connection)
    local instance = setmetatable({}, RedisTagsProvider)
    instance.open_connection = open_connection
    instance.close_connection = close_connection

    return instance
end

---@param key string
---@param tag string 
---@return boolean
function RedisTagsProvider:add_key_to_tag(key, tag)
    if not self:connect() then
        return false
    end
    
    local result = self.redis:sadd(tag, key)
    self:disconnect()
    return result ~= nil and result ~= false
end

---@param key string
---@param tag string
---@return boolean
function RedisTagsProvider:remove_key_from_tag(tag, key)
    if not self:connect() then
        return false
    end
    
    local result = self.redis:srem(tag, key)
    self:disconnect()
    return result ~= nil and result ~= false
end

---@param tag string 
---@return boolean 
function RedisTagsProvider:del_by_tag(tag)
    if not self:connect() then
        return false
    end
    
    local keys = self.redis:smembers(tag)
    if keys and #keys > 0 then
        self.redis:del(keys)
    end

    local result = self.redis:del(tag)
    self:disconnect()
    return result ~= nil and result ~= false
end

---@private
---@return boolean
function RedisTagsProvider:connect()
    self.redis = self.open_connection()

    return true
end

---@private
---@return boolean
function RedisTagsProvider:disconnect()
    return self.close_connection(self.redis)
end

return RedisTagsProvider
