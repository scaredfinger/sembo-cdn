---@class HistogramConfig
---@field help string
---@field label_names string[]
---@field label_combinations table[]

---@class Metrics
---@field metrics_dict table
---@field histograms table<string, HistogramConfig>
local Metrics = {}
Metrics.__index = Metrics

---@param metrics_dict { incr: function, set: function, get: function, get_keys: function }
---@return Metrics
function Metrics.new(metrics_dict)
    if not metrics_dict then
        error("Metrics shared dictionary not available")
    end

    local self = setmetatable({
        metrics_dict = metrics_dict,
        histograms = {}
    }, Metrics)

    return self
end

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
---@param label_names? string[]
---@param label_combinations? table[]
function Metrics:register_histogram(name, help, label_names, label_combinations)
    self.histograms[name] = {
        help = help,
        label_names = label_names or {},
        label_combinations = label_combinations or { {} }
    }

    for _, labels in ipairs(label_combinations or { {} }) do
        local key = self:build_key(name, labels)
        self.metrics_dict:set(key .. "_sum", 0)
        self.metrics_dict:set(key .. "_count", 0)
    end
end

---@param name string
---@param value number
---@param labels? table<string, any>
function Metrics:observe_histogram(name, value, labels)
    local key = self:build_key(name, labels)
    local sum_key = key .. "_sum"
    local count_key = key .. "_count"

    self.metrics_dict:incr(sum_key, value)
    self.metrics_dict:incr(count_key, 1)
end

---@return string
function Metrics:generate_prometheus()
    local output = {}

    for name, config in pairs(self.histograms) do
        table.insert(output, "# HELP " .. name .. " " .. config.help)
        table.insert(output, "# TYPE " .. name .. " histogram")

        local keys = self.metrics_dict:get_keys()
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

return Metrics
