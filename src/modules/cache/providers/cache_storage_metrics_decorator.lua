--- @class CacheStorageMetricsDecorator : CacheStorage
--- @field inner CacheStorage
--- @field metrics Metrics
--- @field cache_name string
--- @field __index CacheStorageMetricsDecorator
local CacheStorageMetricsDecorator = {}
CacheStorageMetricsDecorator.__index = CacheStorageMetricsDecorator

--- @param inner CacheStorage
--- @param metrics Metrics
--- @param cache_name string
--- @return CacheStorageMetricsDecorator
function CacheStorageMetricsDecorator:new(inner, metrics, cache_name)
    local instance = setmetatable({
        inner = inner,
        metrics = metrics,
        cache_name = cache_name
    }, CacheStorageMetricsDecorator)
    return instance
end

--- @param key string
--- @return string|nil
function CacheStorageMetricsDecorator:get(key)
    local labels = {
        operation = "get",
        cache_name = self.cache_name
    }
    
    return self.metrics:measure_execution("cache_operation_duration_seconds", labels, function()
        return self.inner:get(key)
    end)
end

--- @param key string
--- @param value string
--- @param tts number|nil
--- @param ttl number|nil
--- @return boolean
function CacheStorageMetricsDecorator:set(key, value, tts, ttl)
    local labels = {
        operation = "set",
        cache_name = self.cache_name
    }
    
    return self.metrics:measure_execution("cache_operation_duration_seconds", labels, function()
        return self.inner:set(key, value, tts, ttl)
    end)
end

--- @param key string
--- @return boolean
function CacheStorageMetricsDecorator:del(key)
    local labels = {
        operation = "delete",
        cache_name = self.cache_name
    }
    
    return self.metrics:measure_execution("cache_operation_duration_seconds", labels, function()
        return self.inner:del(key)
    end)
end

return CacheStorageMetricsDecorator
