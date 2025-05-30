-- Metrics collection and Prometheus formatting
local cjson = require "cjson"
local utils = require "modules.utils"
local _M = {}

-- Shared dictionary for metrics
local metrics_dict = ngx.shared.metrics

-- Metric types
local COUNTER = "counter"
local HISTOGRAM = "histogram"
local GAUGE = "gauge"

-- Initialize metrics storage
function _M.init()
    if not metrics_dict then
        utils.log("error", "Metrics shared dictionary not available")
        return false
    end
    
    -- Initialize counters
    metrics_dict:set("requests_total", 0)
    metrics_dict:set("cache_hits_total", 0)
    metrics_dict:set("cache_misses_total", 0)
    metrics_dict:set("backend_errors_total", 0)
    metrics_dict:set("response_time_sum", 0)
    metrics_dict:set("response_time_count", 0)
    
    utils.log("info", "Metrics initialized")
    return true
end

-- Increment counter
function _M.inc_counter(name, value, labels)
    value = value or 1
    local key = name
    
    if labels then
        key = key .. ":" .. _M.serialize_labels(labels)
    end
    
    local new_val, err = metrics_dict:incr(key, value)
    if not new_val then
        -- Key doesn't exist, set it
        metrics_dict:set(key, value)
        new_val = value
    end
    
    utils.log("debug", "Counter " .. key .. " incremented to " .. new_val)
    return new_val
end

-- Set gauge value
function _M.set_gauge(name, value, labels)
    local key = name
    
    if labels then
        key = key .. ":" .. _M.serialize_labels(labels)
    end
    
    metrics_dict:set(key, value)
    utils.log("debug", "Gauge " .. key .. " set to " .. value)
end

-- Record histogram value (simplified implementation)
function _M.observe_histogram(name, value, labels)
    local base_key = name
    if labels then
        base_key = base_key .. ":" .. _M.serialize_labels(labels)
    end
    
    -- Update sum and count
    local sum_key = base_key .. "_sum"
    local count_key = base_key .. "_count"
    
    local new_sum, err = metrics_dict:incr(sum_key, value)
    if not new_sum then
        metrics_dict:set(sum_key, value)
    end
    
    local new_count, err = metrics_dict:incr(count_key, 1)
    if not new_count then
        metrics_dict:set(count_key, 1)
    end
end

-- Serialize labels for key generation
function _M.serialize_labels(labels)
    local parts = {}
    for k, v in pairs(labels) do
        table.insert(parts, k .. "=" .. v)
    end
    table.sort(parts)
    return table.concat(parts, ",")
end

-- Record request metrics
function _M.record_request(route_pattern, method, status, response_time, cache_status)
    -- Increment total requests
    _M.inc_counter("requests_total", 1, {
        route = route_pattern,
        method = method,
        status = tostring(status)
    })
    
    -- Record response time
    _M.observe_histogram("response_time_seconds", response_time, {
        route = route_pattern,
        method = method
    })
    
    -- Record cache metrics
    if cache_status == "hit" then
        _M.inc_counter("cache_hits_total", 1, { route = route_pattern })
    elseif cache_status == "miss" then
        _M.inc_counter("cache_misses_total", 1, { route = route_pattern })
    end
    
    -- Record backend errors
    if status >= 500 then
        _M.inc_counter("backend_errors_total", 1, { route = route_pattern })
    end
end

-- Generate Prometheus format output
function _M.generate_prometheus()
    local output = {}
    
    -- Add help and type information
    table.insert(output, "# HELP requests_total Total number of requests")
    table.insert(output, "# TYPE requests_total counter")
    
    table.insert(output, "# HELP cache_hits_total Total number of cache hits")
    table.insert(output, "# TYPE cache_hits_total counter")
    
    table.insert(output, "# HELP cache_misses_total Total number of cache misses")
    table.insert(output, "# TYPE cache_misses_total counter")
    
    table.insert(output, "# HELP backend_errors_total Total number of backend errors")
    table.insert(output, "# TYPE backend_errors_total counter")
    
    table.insert(output, "# HELP response_time_seconds Response time histogram")
    table.insert(output, "# TYPE response_time_seconds histogram")
    
    -- Get all keys from shared dict and format them
    local keys = metrics_dict:get_keys()
    for _, key in ipairs(keys) do
        local value = metrics_dict:get(key)
        if value then
            local metric_line = _M.format_prometheus_line(key, value)
            if metric_line then
                table.insert(output, metric_line)
            end
        end
    end
    
    return table.concat(output, "\n") .. "\n"
end

-- Format a single metric line for Prometheus
function _M.format_prometheus_line(key, value)
    -- Parse key to extract metric name and labels
    local metric_name, labels_str = string.match(key, "^([^:]+):?(.*)?$")
    
    if not metric_name then
        return nil
    end
    
    local formatted_line = metric_name
    
    if labels_str and labels_str ~= "" then
        -- Convert serialized labels back to Prometheus format
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

-- Get current metrics summary (for debugging)
function _M.get_summary()
    local summary = {}
    local keys = metrics_dict:get_keys()
    
    for _, key in ipairs(keys) do
        summary[key] = metrics_dict:get(key)
    end
    
    return summary
end

return _M
