--- @class TagsProviderMetricsDecorator : TagsProvider
--- @field inner TagsProvider
--- @field metrics Metrics
--- @field metrics_name string
--- @field provider_name string
--- @field __index TagsProviderMetricsDecorator
local TagsProviderMetricsDecorator = {}
TagsProviderMetricsDecorator.__index = TagsProviderMetricsDecorator

--- @param inner TagsProvider
--- @param metrics Metrics
--- @param metrics_name string
--- @param provider_name string
--- @return TagsProviderMetricsDecorator
function TagsProviderMetricsDecorator:new(inner, metrics, metrics_name, provider_name)
    local instance = setmetatable({
        inner = inner,
        metrics = metrics,
        metrics_name = metrics_name,
        provider_name = provider_name
    }, TagsProviderMetricsDecorator)
    return instance
end

--- @param key string
--- @param tag string 
--- @return boolean
function TagsProviderMetricsDecorator:add_key_to_tag(key, tag)
    local labels = {
        operation = "add_key_to_tag",
        provider = self.provider_name
    }
    
    return self.metrics:measure_execution(self.metrics_name, labels, function()
        return self.inner:add_key_to_tag(key, tag)
    end)
end

--- @param tag string
--- @param key string
--- @return boolean
function TagsProviderMetricsDecorator:remove_key_from_tag(tag, key)
    local labels = {
        operation = "remove_key_from_tag",
        provider = self.provider_name
    }
    
    return self.metrics:measure_execution(self.metrics_name, labels, function()
        return self.inner:remove_key_from_tag(tag, key)
    end)
end

--- @param tag string
--- @return string[]|nil
function TagsProviderMetricsDecorator:get_keys_for_tag(tag)
    local labels = {
        operation = "get_keys_for_tag",
        provider = self.provider_name
    }
    
    return self.metrics:measure_execution(self.metrics_name, labels, function()
        return self.inner:get_keys_for_tag(tag)
    end)
end

--- @param tag string 
--- @return boolean 
function TagsProviderMetricsDecorator:del_by_tag(tag)
    local labels = {
        operation = "del_by_tag",
        provider = self.provider_name
    }
    
    return self.metrics:measure_execution(self.metrics_name, labels, function()
        return self.inner:del_by_tag(tag)
    end)
end

return TagsProviderMetricsDecorator
