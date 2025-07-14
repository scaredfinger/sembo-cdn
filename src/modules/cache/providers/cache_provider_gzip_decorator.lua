local CacheProvider = require("modules.cache.providers.cache_provider")

--- @class CacheProviderGzipDecorator : CacheProvider
--- @field decorated_provider CacheProvider
--- @field deflate_fn function
--- @field inflate_fn function
--- @field encode_base64_fn function
--- @field decode_base64_fn function
--- @field __index CacheProviderGzipDecorator
local CacheProviderGzipDecorator = {}
CacheProviderGzipDecorator.__index = CacheProviderGzipDecorator
setmetatable(CacheProviderGzipDecorator, {__index = CacheProvider})

--- @param decorated_provider CacheProvider
--- @param deflate_fn function|nil
--- @param inflate_fn function|nil
--- @param encode_base64_fn function|nil
--- @param decode_base64_fn function|nil
--- @return CacheProviderGzipDecorator
function CacheProviderGzipDecorator:new(decorated_provider, deflate_fn, inflate_fn, encode_base64_fn, decode_base64_fn)
    local instance = {
        decorated_provider = decorated_provider,
        deflate_fn = deflate_fn,
        inflate_fn = inflate_fn,
        encode_base64_fn = encode_base64_fn,
        decode_base64_fn = decode_base64_fn
    }
    setmetatable(instance, self)
    return instance
end

--- @param key string
--- @return any|nil
function CacheProviderGzipDecorator:get(key)
    local compressed_value = self.decorated_provider:get(key)
    if not compressed_value then
        return nil
    end
    
    local decompressed_value = self.decode_base64_fn(compressed_value)
    if not decompressed_value then
        return nil
    end
    
    return self.inflate_fn(decompressed_value)
end

--- @param key string
--- @param value any
--- @param tts number|nil
--- @param ttl number|nil
--- @return boolean
function CacheProviderGzipDecorator:set(key, value, tts, ttl)
    local compressed_value = self.deflate_fn(value)
    if not compressed_value then
        return false
    end
    
    local encoded_value = self.encode_base64_fn(compressed_value)
    return self.decorated_provider:set(key, encoded_value, tts, ttl)
end

--- @param key string
--- @return boolean
function CacheProviderGzipDecorator:del(key)
    return self.decorated_provider:del(key)
end

return CacheProviderGzipDecorator