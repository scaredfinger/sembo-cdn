-- Unit tests for metrics module
-- Note: These tests require ngx.shared.metrics to be available
-- In actual testing environment, this would be mocked

describe("metrics module", function()
    local metrics = require "modules.metrics"
    
    -- Mock ngx.shared.metrics if not available
    if not ngx.shared then
        ngx.shared = {
            metrics = {
                _data = {},
                set = function(self, key, value)
                    self._data[key] = value
                    return true
                end,
                get = function(self, key)
                    return self._data[key]
                end,
                incr = function(self, key, value)
                    value = value or 1
                    local current = self._data[key] or 0
                    self._data[key] = current + value
                    return self._data[key]
                end,
                get_keys = function(self)
                    local keys = {}
                    for k, v in pairs(self._data) do
                        table.insert(keys, k)
                    end
                    return keys
                end
            }
        }
    end
    
    before_each(function()
        -- Clear metrics before each test
        if ngx.shared.metrics._data then
            ngx.shared.metrics._data = {}
        end
        metrics.init()
    end)
    
    describe("init", function()
        it("should initialize basic counters", function()
            assert.is_true(metrics.init())
            assert.equals(0, ngx.shared.metrics:get("requests_total"))
            assert.equals(0, ngx.shared.metrics:get("cache_hits_total"))
        end)
    end)
    
    describe("inc_counter", function()
        it("should increment counter without labels", function()
            local value = metrics.inc_counter("test_counter", 1)
            assert.equals(1, value)
        end)
        
        it("should increment counter with labels", function()
            local value = metrics.inc_counter("test_counter", 1, { route = "test" })
            assert.equals(1, value)
        end)
        
        it("should increment existing counter", function()
            metrics.inc_counter("test_counter", 5)
            local value = metrics.inc_counter("test_counter", 3)
            assert.equals(8, value)
        end)
    end)
    
    describe("serialize_labels", function()
        it("should serialize single label", function()
            local result = metrics.serialize_labels({ route = "test" })
            assert.equals("route=test", result)
        end)
        
        it("should serialize multiple labels sorted", function()
            local result = metrics.serialize_labels({ route = "test", method = "GET" })
            assert.equals("method=GET,route=test", result)
        end)
    end)
    
    describe("record_request", function()
        it("should record all request metrics", function()
            metrics.record_request("test/[id]", "GET", 200, 0.5, "hit")
            
            -- Check that counters were incremented
            local requests = ngx.shared.metrics:get("requests_total:method=GET,route=test/[id],status=200")
            assert.equals(1, requests)
            
            local cache_hits = ngx.shared.metrics:get("cache_hits_total:route=test/[id]")
            assert.equals(1, cache_hits)
        end)
    end)
    
    describe("format_prometheus_line", function()
        it("should format simple metric", function()
            local line = metrics.format_prometheus_line("requests_total", 42)
            assert.equals("requests_total 42", line)
        end)
        
        it("should format metric with labels", function()
            local line = metrics.format_prometheus_line("requests_total:method=GET,route=test", 42)
            assert.equals('requests_total{method="GET",route="test"} 42', line)
        end)
    end)
    
    describe("generate_prometheus", function()
        it("should generate valid Prometheus output", function()
            metrics.inc_counter("requests_total", 1)
            local output = metrics.generate_prometheus()
            
            assert.is_string(output)
            assert.is_true(string.find(output, "# HELP") ~= nil)
            assert.is_true(string.find(output, "# TYPE") ~= nil)
            assert.is_true(string.find(output, "requests_total") ~= nil)
        end)
    end)
end)
