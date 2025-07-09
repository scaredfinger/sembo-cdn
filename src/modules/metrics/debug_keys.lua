#!/usr/bin/env lua

-- Debug test to see the keys being generated
local Metrics = require "src.modules.metrics.index"

-- Mock ngx.shared.metrics
local mock_metrics = {
    data = {},
    get = function(self, key) return self.data[key] end,
    set = function(self, key, value) 
        print("SET: " .. key .. " = " .. value)
        self.data[key] = value 
    end,
    incr = function(self, key, value) 
        print("INCR: " .. key .. " += " .. (value or 1))
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

-- Register a test metric
metrics:register_histogram("test_metric", {method={"GET"}})
print("\nKeys after registration:")
for _, key in ipairs(mock_metrics:get_keys()) do
    print("  " .. key)
end

metrics:observe_histogram("test_metric", 0.1, {method="GET"})
print("\nKeys after observation:")
for _, key in ipairs(mock_metrics:get_keys()) do
    print("  " .. key .. " = " .. mock_metrics:get(key))
end
