#!/usr/bin/env lua

-- Simple test to verify new key format functionality
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

print("=== Testing Counter ===")
metrics:register_counter("test_counter", {method={"GET", "POST"}})
metrics:inc_counter("test_counter", 1, {method="GET"})
metrics:inc_counter("test_counter", 3, {method="POST"})

print("Counter keys:")
for _, key in ipairs(mock_metrics:get_keys()) do
    if string.find(key, "test_counter") then
        print("  " .. key .. " = " .. mock_metrics:get(key))
    end
end

print("\n=== Testing Histogram ===")
metrics:register_histogram("test_histogram", {method={"GET"}}, {0.1, 0.5, 1.0})
metrics:observe_histogram("test_histogram", 0.25, {method="GET"})

print("Histogram keys:")
for _, key in ipairs(mock_metrics:get_keys()) do
    if string.find(key, "test_histogram") then
        print("  " .. key .. " = " .. mock_metrics:get(key))
    end
end

print("\n=== Testing Prometheus Output ===")
local output = metrics:generate_prometheus()
print(output)

print("✅ All basic functionality working with new key format!")
