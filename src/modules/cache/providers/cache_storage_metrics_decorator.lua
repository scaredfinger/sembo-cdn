--- @class CacheStorageMetricsDecorator : CacheStorage
--- @field inner CacheStorage
--- @field metrics Metrics
--- @field metrics_name string
--- @field cache_name string
--- @field __index CacheStorageMetricsDecorator
local CacheStorageMetricsDecorator = {}
CacheStorageMetricsDecorator.__index = CacheStorageMetricsDecorator

--- @param inner CacheStorage
--- @param metrics Metrics
--- @param metrics_name string
--- @param cache_name string
--- @return CacheStorageMetricsDecorator
function CacheStorageMetricsDecorator:new(inner, metrics, metrics_name, cache_name)
    local instance = setmetatable({
        inner = inner,
        metrics = metrics,
        metrics_name = metrics_name,
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
    
    return self.metrics:measure_execution(self.metrics_name, labels, function()
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
    
    return self.metrics:measure_execution(self.metrics_name, labels, function()
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
    
    return self.metrics:measure_execution(self.metrics_name, labels, function()
        return self.inner:del(key)
    end)
end

return CacheStorageMetricsDecorator
