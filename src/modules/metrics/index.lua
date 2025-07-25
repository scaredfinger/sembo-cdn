--- @class CounterConfig
--- @field label_values table<string, string[]>

--- @class HistogramConfig
--- @field label_values table<string, string[]>
--- @field buckets number[]

--- @class GaugeConfig
--- @field label_values table<string, string[]>

--- @class Metrics
--- @field metrics_dict SharedDictionary
--- @field histograms table<string, HistogramConfig>
--- @field counters table<string, CounterConfig>
--- @field gauges table<string, GaugeConfig>
--- @field log_error fun(msg: string, ...: any)
--- @field __index Metrics
local Metrics = {}
Metrics.__index = Metrics

--- @param metrics_dict SharedDictionary
--- @param log_error fun(msg: string, ...: any)
--- @return Metrics
function Metrics.new(metrics_dict, log_error)
    if not metrics_dict then
        log_error("Metrics shared dictionary not available")
        error("Metrics shared dictionary not available")
    end

    local instance = setmetatable({
        metrics_dict = metrics_dict,
        histograms = {},
        counters = {},
        gauges = {},
        log_error = log_error
    }, Metrics)

    return instance
end

--- @param base_name string
--- @param value number
--- @param labels? table<string, any>
function Metrics:observe_histogram_success(base_name, value, labels)
    local histogram_name = base_name
    local success_labels = labels or {}
    success_labels.success = "true"
    self:_observe_histogram(histogram_name, value, success_labels)
end

--- @param base_name string
--- @param value number
--- @param labels? table<string, any>
function Metrics:observe_histogram_failure(base_name, value, labels)
    local histogram_name = base_name
    local failure_labels = labels or {}
    failure_labels.success = "false"
    self:_observe_histogram(histogram_name, value, failure_labels)
end

--- @param histogram_name string
--- @param labels table<string, any>
--- @param func function
--- @param ... any
function Metrics:measure_execution(histogram_name, labels, func, ...)
    local start_time = ngx.now()
    local success, result = pcall(func, ...)
    local duration = ngx.now() - start_time
    
    if success then
        self:observe_histogram_success(histogram_name, duration, labels)
        return result
    else
        self:observe_histogram_failure(histogram_name, duration, labels)
        error(result)
    end
end

--- @param name string
--- @param value number
--- @param labels? table<string, any>
--- @private
function Metrics:_observe_histogram(name, value, labels)
    local histogram_config = self.histograms[name]
    if not histogram_config then
        self.log_error("Histogram not registered: " .. name)
    end

    local sum_key = self:_build_key(name .. "_sum", labels)
    if not self.metrics_dict:get(sum_key) then
        self.log_error("Histogram sum key not found: " .. sum_key)
    else
        self.metrics_dict:incr(sum_key, value)
    end

    local count_key = self:_build_key(name .. "_count", labels)
    if not self.metrics_dict:get(count_key) then
        self.log_error("Histogram count key not found: " .. count_key)
    else
        self.metrics_dict:incr(count_key, 1)
    end

    for _, bucket in ipairs(histogram_config.buckets) do
        if value <= bucket then
            local bucket_labels = {}
            if labels then
                for k, v in pairs(labels) do
                    bucket_labels[k] = v
                end
            end
            bucket_labels.le = tostring(bucket)
            local bucket_key = self:_build_key(name .. "_bucket", bucket_labels)
            if not self.metrics_dict:get(bucket_key) then
                self.log_error("Histogram bucket key not found: " .. bucket_key)
            else
                self.metrics_dict:incr(bucket_key, 1)
            end
        end
    end

    local inf_labels = {}
    if labels then
        for k, v in pairs(labels) do
            inf_labels[k] = v
        end
    end
    inf_labels.le = "+Inf"
    local inf_key = self:_build_key(name .. "_bucket", inf_labels)
    self.metrics_dict:incr(inf_key, 1)
end

--- @private
--- @param name string
--- @param labels? table<string, any>
--- @return string
function Metrics:_build_key(name, labels)
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

--- @param name string
--- @param value? number
--- @param labels? table<string, any>
function Metrics:inc_counter(name, value, labels)
    local counter_config = self.counters[name]
    if not counter_config then
        self.log_error("Counter not registered: " .. name)
    end

    value = value or 1
    local key = self:_build_key(name, labels)

    if not self.metrics_dict:get(key) then
        self.log_error("Counter key not found: " .. key)
    else
        self.metrics_dict:incr(key, value)
    end
end

--- @param name string
--- @param value number
--- @param labels? table<string, any>
function Metrics:set_gauge(name, value, labels)
    local gauge_config = self.gauges[name]
    if not gauge_config then
        self.log_error("Gauge not registered: " .. name)
    end

    local key = self:_build_key(name, labels)

    if not self.metrics_dict:get(key) then
        self.log_error("Gauge key not found: " .. key)
    else
        self.metrics_dict:set(key, value)
    end
end

--- @param name string
--- @param value? number
--- @param labels? table<string, any>
function Metrics:inc_gauge(name, value, labels)
    local gauge_config = self.gauges[name]
    if not gauge_config then
        self.log_error("Gauge not registered: " .. name)
    end

    value = value or 1
    local key = self:_build_key(name, labels)

    if not self.metrics_dict:get(key) then
        self.log_error("Gauge key not found: " .. key)
    else
        self.metrics_dict:incr(key, value)
    end
end

--- @param name string
--- @param value? number
--- @param labels? table<string, any>
function Metrics:dec_gauge(name, value, labels)
    local gauge_config = self.gauges[name]
    if not gauge_config then
        self.log_error("Gauge not registered: " .. name)
    end

    value = value or 1
    local key = self:_build_key(name, labels)

    if not self.metrics_dict:get(key) then
        self.log_error("Gauge key not found: " .. key)
    else
        self.metrics_dict:incr(key, -value)
    end
end

--- @param name string
--- @param label_values? table<string, string[]>
--- @param buckets? number[]
function Metrics:register_histogram(name, label_values, buckets)
    -- Check if already registered
    if self.histograms[name] then
        return
    end

    label_values = label_values or {}
    -- Automatically add success label if not present
    if not label_values.success then
        label_values.success = { "true", "false" }
    end
    buckets = buckets or { 0.005, 0.01, 0.025, 0.05, 0.075, 0.1, 0.25, 0.5, 0.75, 1.0, 2.5, 5.0, 7.5, 10.0 }

    local label_combinations = self:_generate_label_combinations(label_values)

    self.histograms[name] = {
        label_values = label_values,
        buckets = buckets
    }

    for _, labels in ipairs(label_combinations) do
        local sum_key = self:_build_key(name .. "_sum", labels)
        local count_key = self:_build_key(name .. "_count", labels)

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
            local bucket_key = self:_build_key(name .. "_bucket", bucket_labels)
            if not self.metrics_dict:get(bucket_key) then
                self.metrics_dict:set(bucket_key, 0)
            end
        end

        local inf_labels = {}
        for k, v in pairs(labels) do
            inf_labels[k] = v
        end
        inf_labels.le = "+Inf"
        local inf_key = self:_build_key(name .. "_bucket", inf_labels)
        if not self.metrics_dict:get(inf_key) then
            self.metrics_dict:set(inf_key, 0)
        end
    end
end

--- @private
--- @param label_values table<string, string[]>
--- @return table[]
function Metrics:_generate_label_combinations(label_values)
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
            self.log_error("No values provided for label: " .. label_name)
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

--- @param name string
--- @param label_values? table<string, string[]>
function Metrics:register_counter(name, label_values)
    -- Check if already registered
    if self.counters[name] then
        return
    end

    label_values = label_values or {}

    local label_combinations = self:_generate_label_combinations(label_values)

    self.counters[name] = {
        label_values = label_values
    }

    for _, labels in ipairs(label_combinations) do
        local key = self:_build_key(name, labels)
        -- Only set if not already exists
        if not self.metrics_dict:get(key) then
            self.metrics_dict:set(key, 0)
        end
    end
end

--- @param name string
--- @param label_values? table<string, string[]>
function Metrics:register_gauge(name, label_values)
    -- Check if already registered
    if self.gauges[name] then
        return
    end

    label_values = label_values or {}

    local label_combinations = self:_generate_label_combinations(label_values)

    self.gauges[name] = {
        label_values = label_values
    }

    for _, labels in ipairs(label_combinations) do
        local key = self:_build_key(name, labels)
        -- Only set if not already exists
        if not self.metrics_dict:get(key) then
            self.metrics_dict:set(key, 0)
        end
    end
end

--- @return string
function Metrics:generate_prometheus()
    local output = {}

    for name, _ in pairs(self.counters) do
        table.insert(output, "# HELP " .. name .. " ")
        table.insert(output, "# TYPE " .. name .. " counter")
    end

    for name, _ in pairs(self.gauges) do
        table.insert(output, "# HELP " .. name .. " ")
        table.insert(output, "# TYPE " .. name .. " gauge")
    end

    for name, _ in pairs(self.histograms) do
        table.insert(output, "# HELP " .. name .. " ")
        table.insert(output, "# TYPE " .. name .. " histogram")
    end

    local keys = self.metrics_dict:get_keys(0)
    for _, key in ipairs(keys) do
        local value = self.metrics_dict:get(key)
        if value then
            local numeric_value = tonumber(value)
            if numeric_value then
                local line = self:_format_prometheus_line(key, numeric_value)
                if line then
                    table.insert(output, line)
                end
            end
        end
    end

    return table.concat(output, "\n") .. "\n"
end

--- @private
--- @param key string
--- @param value number
--- @return string?
function Metrics:_format_prometheus_line(key, value)
    if not key then
        return nil
    end

    return key .. " " .. value
end

--- @return table<string, number>
function Metrics:get_summary()
    local summary = {}
    local keys = self.metrics_dict:get_keys()

    for _, key in ipairs(keys) do
        summary[key] = self.metrics_dict:get(key)
    end

    return summary
end

return Metrics
