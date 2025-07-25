--- @class CacheStorageMetricsDecorator : CacheStorage
--- @field inner CacheStorage
--- @field metrics Metrics
--- @field cache_name string
--- @field now fun(): number
--- @field __index CacheStorageMetricsDecorator
local CacheStorageMetricsDecorator = {}
CacheStorageMetricsDecorator.__index = CacheStorageMetricsDecorator

--- @param inner CacheStorage
--- @param metrics Metrics
--- @param cache_name string
--- @param now fun(): number
--- @return CacheStorageMetricsDecorator
function CacheStorageMetricsDecorator:new(inner, metrics, cache_name, now)
    local instance = setmetatable({
        inner = inner,
        metrics = metrics,
        cache_name = cache_name,
        now = now
    }, CacheStorageMetricsDecorator)
    return instance
end

--- @param key string
--- @return string|nil
function CacheStorageMetricsDecorator:get(key)
    local start_time = self.now()
    local operation = "get"
    local labels = {
        operation = operation,
        cache_name = self.cache_name
    }
    
    local success, result = pcall(function()
        return self.inner:get(key)
    end)
    
    local duration = self.now() - start_time
    local metric_name = "cache_operation_duration_seconds"
    
    if success then
        self.metrics:observe_histogram_success(metric_name, duration, labels)
        return result
    else
        self.metrics:observe_histogram_failure(metric_name, duration, labels)
        error(result)
    end
end

--- @param key string
--- @param value string
--- @param tts number|nil
--- @param ttl number|nil
--- @return boolean
function CacheStorageMetricsDecorator:set(key, value, tts, ttl)
    local start_time = self.now()
    local operation = "set"
    local labels = {
        operation = operation,
        cache_name = self.cache_name
    }
    
    local success, result = pcall(function()
        return self.inner:set(key, value, tts, ttl)
    end)
    
    local duration = self.now() - start_time
    local metric_name = "cache_operation_duration_seconds"
    
    if success then
        self.metrics:observe_histogram_success(metric_name, duration, labels)
        return result
    else
        self.metrics:observe_histogram_failure(metric_name, duration, labels)
        error(result)
    end
end

--- @param key string
--- @return boolean
function CacheStorageMetricsDecorator:del(key)
    local start_time = self.now()
    local operation = "delete"
    local labels = {
        operation = operation,
        cache_name = self.cache_name
    }
    
    local success, result = pcall(function()
        return self.inner:del(key)
    end)
    
    local duration = self.now() - start_time
    local metric_name = "cache_operation_duration_seconds"
    
    if success then
        self.metrics:observe_histogram_success(metric_name, duration, labels)
        return result
    else
        self.metrics:observe_histogram_failure(metric_name, duration, labels)
        error(result)
    end
end

return CacheStorageMetricsDecorator
