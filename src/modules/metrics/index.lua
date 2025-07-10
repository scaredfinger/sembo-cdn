---@class CompositeMetricConfig
---@field name string
---@field label_values? table<string, string[]>
---@field histogram_suffix? string
---@field counter_suffix? string
---@field buckets? number[]

---@class CounterConfig
---@field label_values table<string, string[]>

---@class HistogramConfig
---@field label_values table<string, string[]>
---@field buckets number[]

---@class CompositeConfig
---@field label_values table<string, string[]>
---@field histogram_suffix string
---@field counter_suffix string
---@field buckets number[]

---@class Metrics
---@field metrics_dict SharedDictionary
---@field histograms table<string, HistogramConfig>
---@field counters table<string, CounterConfig>
---@field composites table<string, CompositeConfig>
local Metrics = {}
Metrics.__index = Metrics

---@param metrics_dict SharedDictionary
---@return Metrics
function Metrics.new(metrics_dict)
    if not metrics_dict then
        error("Metrics shared dictionary not available")
    end

    local self = setmetatable({
        metrics_dict = metrics_dict,
        histograms = {},
        counters = {},
        composites = {}
    }, Metrics)

    return self
end

---@private
---@param label_values table<string, string[]>
---@return table[]
function Metrics:generate_label_combinations(label_values)
    if not label_values or next(label_values) == nil then
        return { {} }
    end

    local label_names = {}
    for label_name, _ in pairs(label_values) do
        table.insert(label_names, label_name)
    end
    table.sort(label_names)

    local function cartesian_product(arrays)
        if #arrays == 0 then
            return { {} }
        end

        local result = {}
        local first_array = arrays[1]
        local rest_arrays = {}
        for i = 2, #arrays do
            table.insert(rest_arrays, arrays[i])
        end

        local rest_combinations = cartesian_product(rest_arrays)

        for _, first_value in ipairs(first_array) do
            for _, rest_combination in ipairs(rest_combinations) do
                local combination = { first_value }
                for _, value in ipairs(rest_combination) do
                    table.insert(combination, value)
                end
                table.insert(result, combination)
            end
        end

        return result
    end

    local value_arrays = {}
    for _, label_name in ipairs(label_names) do
        local values = label_values[label_name]
        if not values then
            error("No values provided for label: " .. label_name)
        end
        table.insert(value_arrays, values)
    end

    local combinations = cartesian_product(value_arrays)

    local label_combinations = {}
    for _, combination in ipairs(combinations) do
        local labels = {}
        for i, label_name in ipairs(label_names) do
            labels[label_name] = combination[i]
        end
        table.insert(label_combinations, labels)
    end

    return label_combinations
end

---@private
---@param name string
---@param labels? table<string, any>
---@return string
function Metrics:build_key(name, labels)
    if not labels or next(labels) == nil then
        return name
    end

    local parts = {}
    for k, v in pairs(labels) do
        table.insert(parts, k .. '="' .. tostring(v) .. '"')
    end
    table.sort(parts)
    return name .. "{" .. table.concat(parts, ",") .. "}"
end

---@private
---@param key string
---@param value number
---@return string?
function Metrics:format_prometheus_line(key, value)
    if not key then
        return nil
    end
    
    return key .. " " .. value
end

---@param name string
---@param label_values? table<string, string[]>
---@param buckets? number[]
function Metrics:register_histogram(name, label_values, buckets)
    -- Check if already registered
    if self.histograms[name] then
        return
    end
    
    label_values = label_values or {}
    buckets = buckets or { 0.005, 0.01, 0.025, 0.05, 0.075, 0.1, 0.25, 0.5, 0.75, 1.0, 2.5, 5.0, 7.5, 10.0 }

    local label_combinations = self:generate_label_combinations(label_values)

    self.histograms[name] = {
        label_values = label_values,
        buckets = buckets
    }

    for _, labels in ipairs(label_combinations) do
        local sum_key = self:build_key(name .. "_sum", labels)
        local count_key = self:build_key(name .. "_count", labels)
        
        -- Only set if not already exists
        if not self.metrics_dict:get(sum_key) then
            self.metrics_dict:set(sum_key, 0)
        end
        if not self.metrics_dict:get(count_key) then
            self.metrics_dict:set(count_key, 0)
        end

        for _, bucket in ipairs(buckets) do
            local bucket_labels = {}
            for k, v in pairs(labels) do
                bucket_labels[k] = v
            end
            bucket_labels.le = tostring(bucket)
            local bucket_key = self:build_key(name .. "_bucket", bucket_labels)
            if not self.metrics_dict:get(bucket_key) then
                self.metrics_dict:set(bucket_key, 0)
            end
        end
        
        local inf_labels = {}
        for k, v in pairs(labels) do
            inf_labels[k] = v
        end
        inf_labels.le = "+Inf"
        local inf_key = self:build_key(name .. "_bucket", inf_labels)
        if not self.metrics_dict:get(inf_key) then
            self.metrics_dict:set(inf_key, 0)
        end
    end
end

---@param name string
---@param value number
---@param labels? table<string, any>
function Metrics:observe_histogram(name, value, labels)
    local histogram_config = self.histograms[name]
    if not histogram_config then
        error("Histogram not registered: " .. name)
    end

    local sum_key = self:build_key(name .. "_sum", labels)
    self.metrics_dict:incr(sum_key, value)

    local count_key = self:build_key(name .. "_count", labels)
    self.metrics_dict:incr(count_key, 1)

    for _, bucket in ipairs(histogram_config.buckets) do
        if value <= bucket then
            local bucket_labels = {}
            if labels then
                for k, v in pairs(labels) do
                    bucket_labels[k] = v
                end
            end
            bucket_labels.le = tostring(bucket)
            local bucket_key = self:build_key(name .. "_bucket", bucket_labels)
            self.metrics_dict:incr(bucket_key, 1)
        end
    end

    local inf_labels = {}
    if labels then
        for k, v in pairs(labels) do
            inf_labels[k] = v
        end
    end
    inf_labels.le = "+Inf"
    local inf_key = self:build_key(name .. "_bucket", inf_labels)
    self.metrics_dict:incr(inf_key, 1)
end

---@param name string
---@param label_values? table<string, string[]>
function Metrics:register_counter(name, label_values)
    -- Check if already registered
    if self.counters[name] then
        return
    end
    
    label_values = label_values or {}

    local label_combinations = self:generate_label_combinations(label_values)

    self.counters[name] = {
        label_values = label_values
    }

    for _, labels in ipairs(label_combinations) do
        local key = self:build_key(name, labels)
        -- Only set if not already exists
        if not self.metrics_dict:get(key) then
            self.metrics_dict:set(key, 0)
        end
    end
end

---@param name string
---@param value? number
---@param labels? table<string, any>
function Metrics:inc_counter(name, value, labels)
    local counter_config = self.counters[name]
    if not counter_config then
        error("Counter not registered: " .. name)
    end

    value = value or 1
    local key = self:build_key(name, labels)

    self.metrics_dict:incr(key, value)
end

---@param config CompositeMetricConfig
function Metrics:register_composite(config)
    -- Check if already registered
    if self.composites[config.name] then
        return
    end
    
    local label_values = config.label_values or {}
    local histogram_suffix = config.histogram_suffix or "_seconds"
    local counter_suffix = config.counter_suffix or "_total"
    local buckets = config.buckets or { 0.005, 0.01, 0.025, 0.05, 0.075, 0.1, 0.25, 0.5, 0.75, 1.0, 2.5, 5.0, 7.5, 10.0 }

    local histogram_name = "success_" .. config.name .. histogram_suffix
    local counter_name = "failed_" .. config.name .. counter_suffix

    self.composites[config.name] = {
        label_values = label_values,
        histogram_suffix = histogram_suffix,
        counter_suffix = counter_suffix,
        buckets = buckets
    }

    self:register_histogram(histogram_name, label_values, buckets)
    self:register_counter(counter_name, label_values)
end

---@param base_name string
---@param value number
---@param labels? table<string, any>
function Metrics:observe_composite_success(base_name, value, labels)
    local composite_config = self.composites[base_name]
    if not composite_config then
        error("Composite metric not registered: " .. base_name)
    end

    local histogram_name = "success_" .. base_name .. composite_config.histogram_suffix
    self:observe_histogram(histogram_name, value, labels)
end

---@param base_name string
---@param value? number
---@param labels? table<string, any>
function Metrics:inc_composite_failure(base_name, value, labels)
    local composite_config = self.composites[base_name]
    if not composite_config then
        error("Composite metric not registered: " .. base_name)
    end

    local counter_name = "failed_" .. base_name .. composite_config.counter_suffix
    self:inc_counter(counter_name, value, labels)
end

---@return string
function Metrics:generate_prometheus()
    local output = {}

    for name, _ in pairs(self.counters) do
        table.insert(output, "# HELP " .. name .. " ")
        table.insert(output, "# TYPE " .. name .. " counter")
    end

    for name, _ in pairs(self.histograms) do
        table.insert(output, "# HELP " .. name .. " ")
        table.insert(output, "# TYPE " .. name .. " histogram")
    end

    local keys = self.metrics_dict:get_keys(0)
    for _, key in ipairs(keys) do
        local value = self.metrics_dict:get(key)
        if value then
            local line = self:format_prometheus_line(key, value)
            if line then
                table.insert(output, line)
            end
        end
    end

    return table.concat(output, "\n") .. "\n"
end

---@return table<string, number>
function Metrics:get_summary()
    local summary = {}
    local keys = self.metrics_dict:get_keys()

    for _, key in ipairs(keys) do
        summary[key] = self.metrics_dict:get(key)
    end

    return summary
end

return Metrics
