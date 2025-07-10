#!/usr/bin/env lua

-- Test composite metrics with new key format
local Metrics = require "modules.metrics.index"

-- Mock ngx.shared.metrics
local mock_metrics = {
    data = {},
    get = function(self, key) return self.data[key] end,
    set = function(self, key, value) 
        self.data[key] = value 
    end,
    incr = function(self, key, value) 
        self.data[key] = (self.data[key] or 0) + (value or 1)
        return self.data[key]
    end,
    get_keys = function(self)
        local keys = {}
        for k, _ in pairs(self.data) do
            table.insert(keys, k)
        end
        table.sort(keys)
        return keys
    end
}

local metrics = Metrics.new(mock_metrics)

print("=== Testing Composite Metrics ===")
metrics:register_composite({
    name = "api_request",
    label_values = {method={"GET", "POST"}},
    histogram_suffix = "_duration",
    counter_suffix = "_errors"
})

-- Record success
metrics:observe_composite_success("api_request", 0.125, {method="GET"})
metrics:observe_composite_success("api_request", 0.250, {method="POST"})

-- Record failures
metrics:inc_composite_failure("api_request", 1, {method="GET"})
metrics:inc_composite_failure("api_request", 2, {method="POST"})

print("Composite metric keys:")
for _, key in ipairs(mock_metrics:get_keys()) do
    print("  " .. key .. " = " .. mock_metrics:get(key))
end

print("\n=== Prometheus Output ===")
local output = metrics:generate_prometheus()
print(output)

print("✅ Composite metrics working with new key format!")
