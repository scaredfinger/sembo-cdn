--- @class CacheProviderGzipDecorator : CacheStorage
--- @field inner CacheStorage
--- @field decode function
--- @field encode function
--- @field __index CacheProviderGzipDecorator
local CacheProviderCompressionDecorator = {}
CacheProviderCompressionDecorator.__index = CacheProviderCompressionDecorator

--- @param inner CacheStorage
--- @param encode function|nil
--- @param decode function|nil
--- @return CacheProviderGzipDecorator
function CacheProviderCompressionDecorator:new(inner, encode, decode)
    local instance = setmetatable({
        inner = inner,
        encode = encode,
        decode = decode
    }, CacheProviderCompressionDecorator)
    return instance
end

--- @param key string
--- @return string|nil
function CacheProviderCompressionDecorator:get(key)
    local compressed_value = self.inner:get(key)
    if not compressed_value then
        return nil
    end
    
    local result = self.decode(compressed_value)
    return result
end

--- @param key string
--- @param value string
--- @param tts number|nil
--- @param ttl number|nil
--- @return boolean
function CacheProviderCompressionDecorator:set(key, value, tts, ttl)
    local compressed_value = self.encode(value)
    if not compressed_value then
        return false
    end
    
    return self.inner:set(key, compressed_value, tts, ttl)
end

--- @param key string
--- @return boolean
function CacheProviderCompressionDecorator:del(key)
    return self.inner:del(key)
end

return CacheProviderCompressionDecorator