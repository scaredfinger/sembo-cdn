#!/usr/bin/env lua

-- Quick test to verify empty help output
local Metrics = require "modules.metrics.index"

-- Mock ngx.shared.metrics
local mock_metrics = {
    data = {},
    get = function(self, key) return self.data[key] end,
    set = function(self, key, value) self.data[key] = value end,
    incr = function(self, key, value) 
        self.data[key] = (self.data[key] or 0) + (value or 1)
        return self.data[key]
    end,
    get_keys = function(self)
        local keys = {}
        for k, _ in pairs(self.data) do
            table.insert(keys, k)
        end
        return keys
    end
}

local metrics = Metrics.new(mock_metrics)

-- Register a test metric
metrics:register_histogram("test_metric", {method={"GET"}})
metrics:observe_histogram("test_metric", 0.1, {method="GET"})

-- Generate output
local output = metrics:generate_prometheus()
print(output)

-- Check for empty help
if string.find(output, "# HELP test_metric ") then
    print("✅ Empty help text found correctly")
else
    print("❌ Help text format incorrect")
end
