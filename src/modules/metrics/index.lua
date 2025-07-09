---@class CompositeMetricConfig
---@field name string
---@field help string
---@field label_values? table<string, string[]>
---@field histogram_suffix? string
---@field counter_suffix? string
---@field buckets? number[]

---@class CounterConfig
---@field help string
---@field label_values table<string, string[]>

---@class HistogramConfig
---@field help string
---@field label_values table<string, string[]>
---@field buckets number[]

---@class CompositeConfig
---@field help string
---@field label_values table<string, string[]>
---@field histogram_suffix string
---@field counter_suffix string
---@field buckets number[]

---@class Metrics
---@field metrics_dict table
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
        table.insert(parts, k .. "=" .. tostring(v))
    end
    table.sort(parts)
    return name .. ":" .. table.concat(parts, ",")
end

---@private
---@param key string
---@param value number
---@return string?
function Metrics:format_prometheus_line(key, value)
    local metric_name, labels_str = string.match(key, "^([^:]+):?(.*)$")

    if not metric_name then
        return nil
    end

    local formatted_line = metric_name

    if labels_str and labels_str ~= "" then
        local labels = {}
        for label_pair in string.gmatch(labels_str, "[^,]+") do
            local k, v = string.match(label_pair, "([^=]+)=(.+)")
            if k and v then
                table.insert(labels, k .. '="' .. v .. '"')
            end
        end

        if #labels > 0 then
            formatted_line = formatted_line .. "{" .. table.concat(labels, ",") .. "}"
        end
    end

    return formatted_line .. " " .. value
end

---@param name string
---@param help string
---@param label_values? table<string, string[]>
---@param buckets? number[]
function Metrics:register_histogram(name, help, label_values, buckets)
    label_values = label_values or {}
    buckets = buckets or { 0.005, 0.01, 0.025, 0.05, 0.075, 0.1, 0.25, 0.5, 0.75, 1.0, 2.5, 5.0, 7.5, 10.0 }

    local label_combinations = self:generate_label_combinations(label_values)

    self.histograms[name] = {
        help = help,
        label_values = label_values,
        buckets = buckets
    }

    for _, labels in ipairs(label_combinations) do
        local key = self:build_key(name, labels)
        self.metrics_dict:set(key .. "_sum", 0)
        self.metrics_dict:set(key .. "_count", 0)

        for _, bucket in ipairs(buckets) do
            self.metrics_dict:set(key .. "_bucket_" .. tostring(bucket), 0)
        end
        self.metrics_dict:set(key .. "_bucket_inf", 0)
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

    local key = self:build_key(name, labels)
    local sum_key = key .. "_sum"
    local count_key = key .. "_count"

    self.metrics_dict:incr(sum_key, value)
    self.metrics_dict:incr(count_key, 1)

    for _, bucket in ipairs(histogram_config.buckets) do
        if value <= bucket then
            self.metrics_dict:incr(key .. "_bucket_" .. tostring(bucket), 1)
        end
    end

    self.metrics_dict:incr(key .. "_bucket_inf", 1)
end

---@param name string
---@param help string
---@param label_values? table<string, string[]>
function Metrics:register_counter(name, help, label_values)
    label_values = label_values or {}

    local label_combinations = self:generate_label_combinations(label_values)

    self.counters[name] = {
        help = help,
        label_values = label_values
    }

    for _, labels in ipairs(label_combinations) do
        local key = self:build_key(name, labels)
        self.metrics_dict:set(key, 0)
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
    local label_values = config.label_values or {}
    local histogram_suffix = config.histogram_suffix or "_seconds"
    local counter_suffix = config.counter_suffix or "_total"
    local buckets = config.buckets or { 0.005, 0.01, 0.025, 0.05, 0.075, 0.1, 0.25, 0.5, 0.75, 1.0, 2.5, 5.0, 7.5, 10.0 }

    local histogram_name = "success_" .. config.name .. histogram_suffix
    local counter_name = "failed_" .. config.name .. counter_suffix

    self.composites[config.name] = {
        help = config.help,
        label_values = label_values,
        histogram_suffix = histogram_suffix,
        counter_suffix = counter_suffix,
        buckets = buckets
    }

    self:register_histogram(histogram_name, config.help .. " (success)", label_values, buckets)
    self:register_counter(counter_name, config.help .. " (failed)", label_values)
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

    for name, config in pairs(self.counters) do
        table.insert(output, "# HELP " .. name .. " " .. config.help)
        table.insert(output, "# TYPE " .. name .. " counter")

        local keys = self.metrics_dict:get_keys()
        for _, key in ipairs(keys) do
            if string.match(key, "^" .. name .. ":") or key == name then
                if not (string.match(key, "_sum$") or string.match(key, "_count$") or string.match(key, "_bucket_")) then
                    local value = self.metrics_dict:get(key)
                    if value then
                        local metric_line = self:format_prometheus_line(key, value)
                        if metric_line then
                            table.insert(output, metric_line)
                        end
                    end
                end
            end
        end
    end

    for name, config in pairs(self.histograms) do
        table.insert(output, "# HELP " .. name .. " " .. config.help)
        table.insert(output, "# TYPE " .. name .. " histogram")

        local keys = self.metrics_dict:get_keys()

        for _, key in ipairs(keys) do
            if string.match(key, "^" .. name .. ".*_bucket_") then
                local value = self.metrics_dict:get(key)
                if value then
                    local metric_line = self:format_prometheus_bucket_line(key, value)
                    if metric_line then
                        table.insert(output, metric_line)
                    end
                end
            end
        end

        for _, key in ipairs(keys) do
            if string.match(key, "^" .. name .. ".*_sum$") or string.match(key, "^" .. name .. ".*_count$") then
                local value = self.metrics_dict:get(key)
                if value then
                    local metric_line = self:format_prometheus_line(key, value)
                    if metric_line then
                        table.insert(output, metric_line)
                    end
                end
            end
        end
    end

    for name, config in pairs(self.composites) do
        table.insert(output, "# HELP " .. name .. " " .. config.help)
        table.insert(output, "# TYPE " .. name .. " histogram")

        local keys = self.metrics_dict:get_keys()

        for _, key in ipairs(keys) do
            if string.match(key, "^" .. name .. ".*_bucket_") then
                local value = self.metrics_dict:get(key)
                if value then
                    local metric_line = self:format_prometheus_bucket_line(key, value)
                    if metric_line then
                        table.insert(output, metric_line)
                    end
                end
            end
        end

        for _, key in ipairs(keys) do
            if string.match(key, "^" .. name .. ".*_sum$") or string.match(key, "^" .. name .. ".*_count$") then
                local value = self.metrics_dict:get(key)
                if value then
                    local metric_line = self:format_prometheus_line(key, value)
                    if metric_line then
                        table.insert(output, metric_line)
                    end
                end
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

---@private
---@param key string
---@param value number
---@return string?
function Metrics:format_prometheus_bucket_line(key, value)
    local base_key, bucket_str = string.match(key, "^(.*)_bucket_(.+)$")

    if not base_key or not bucket_str then
        return nil
    end

    local metric_name, labels_str = string.match(base_key, "^([^:]+):?(.*)$")

    if not metric_name then
        return nil
    end

    local formatted_line = metric_name .. "_bucket"

    local labels = {}

    if labels_str and labels_str ~= "" then
        for label_pair in string.gmatch(labels_str, "[^,]+") do
            local k, v = string.match(label_pair, "([^=]+)=(.+)")
            if k and v then
                table.insert(labels, k .. '="' .. v .. '"')
            end
        end
    end

    local le_value = bucket_str == "inf" and "+Inf" or bucket_str
    table.insert(labels, 'le="' .. le_value .. '"')

    if #labels > 0 then
        formatted_line = formatted_line .. "{" .. table.concat(labels, ",") .. "}"
    end

    return formatted_line .. " " .. value
end

return Metrics
