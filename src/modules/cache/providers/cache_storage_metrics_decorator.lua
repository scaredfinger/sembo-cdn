--- @class CacheStorageMetricsDecorator : CacheStorage
--- @field inner CacheStorage
--- @field metrics Metrics
--- @field metric_name string
--- @field now fun(): number
--- @field get_labels fun(key: string, operation: string): table<string, string>
--- @field __index CacheStorageMetricsDecorator
local CacheStorageMetricsDecorator = {}
CacheStorageMetricsDecorator.__index = CacheStorageMetricsDecorator

--- @param inner CacheStorage
--- @param metrics Metrics
--- @param metric_name string
--- @param now fun(): number
--- @param get_labels fun(key: string, operation: string): table<string, string>
--- @return CacheStorageMetricsDecorator
function CacheStorageMetricsDecorator:new(inner, metrics, metric_name, now, get_labels)
    local instance = setmetatable({
        inner = inner,
        metrics = metrics,
        metric_name = metric_name,
        now = now,
        get_labels = get_labels
    }, CacheStorageMetricsDecorator)
    return instance
end

--- @param key string
--- @return string|nil
function CacheStorageMetricsDecorator:get(key)
    local start_time = self.now()
    local operation = "get"
    local labels = self.get_labels(key, operation)
    
    local success, result = pcall(function()
        return self.inner:get(key)
    end)
    
    local duration = self.now() - start_time
    local metric_name = self.metric_name
    
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
    local labels = self.get_labels(key, operation)
    
    local success, result = pcall(function()
        return self.inner:set(key, value, tts, ttl)
    end)
    
    local duration = self.now() - start_time
    local metric_name = self.metric_name
    
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
    local operation = "del"
    local labels = self.get_labels(key, operation)
    
    local success, result = pcall(function()
        return self.inner:del(key)
    end)
    
    local duration = self.now() - start_time
    local metric_name = self.metric_name
    
    if success then
        self.metrics:observe_histogram_success(metric_name, duration, labels)
        return result
    else
        self.metrics:observe_histogram_failure(metric_name, duration, labels)
        error(result)
    end
end

return CacheStorageMetricsDecorator
