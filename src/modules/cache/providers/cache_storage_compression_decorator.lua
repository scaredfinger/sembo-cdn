--- @class CacheProviderGzipDecorator : CacheStorage
--- @field inner CacheStorage
--- @field decode function
--- @field encode function
--- @field encode_base64_fn function
--- @field decode_base64_fn function
--- @field __index CacheProviderGzipDecorator
local CacheProviderCompressionDecorator = {}
CacheProviderCompressionDecorator.__index = CacheProviderCompressionDecorator

--- @param inner CacheStorage
--- @param encode function|nil
--- @param decode function|nil
--- @param encode_base64_fn function|nil
--- @param decode_base64_fn function|nil
--- @return CacheProviderGzipDecorator
function CacheProviderCompressionDecorator:new(inner, encode, decode, encode_base64_fn, decode_base64_fn)
    local instance = setmetatable({
        inner = inner,
        encode = encode,
        decode = decode,
        encode_base64_fn = encode_base64_fn,
        decode_base64_fn = decode_base64_fn,
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
    
    local decompressed_value = self.decode_base64_fn(compressed_value)
    if not decompressed_value then
        return nil
    end
    
    local result = self.decode(decompressed_value)
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
    
    local b64_encoded_value = self.encode_base64_fn(compressed_value)
    return self.inner:set(key, b64_encoded_value, tts, ttl)
end

--- @param key string
--- @return boolean
function CacheProviderCompressionDecorator:del(key)
    return self.inner:del(key)
end

return CacheProviderCompressionDecorator