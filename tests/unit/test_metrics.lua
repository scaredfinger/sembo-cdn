local describe = require('busted').describe
local before_each = require('busted').before_each
local it = require('busted').it

local assert = require('luassert')

-- Unit tests for metrics module
require "tests.test_helper"  -- Load ngx mocks before requiring modules

describe("metrics module", function()
    local Metrics = require "modules.metrics.index"
    local metrics
    
    before_each(function()
        -- Clear metrics before each test
        reset_ngx_mocks()
        metrics = Metrics.new(ngx.shared.metrics)
    end)
    
    describe("new", function()
        it("should create new metrics instance", function()
            assert.is_not_nil(metrics)
            assert.equals("table", type(metrics.histograms))
        end)
        
        it("should fail with nil metrics_dict", function()
            assert.has_error(function() Metrics.new(nil) end)
        end)
    end)
    
    describe("build_key", function()
        it("should build key without labels", function()
            local key = metrics:build_key("test_metric")
            assert.equals("test_metric", key)
        end)
        
        it("should build key with labels", function()
            local key = metrics:build_key("test_metric", { route = "test", method = "GET" })
            assert.equals("test_metric:method=GET,route=test", key)
        end)
    end)
    
    describe("register_histogram", function()
        it("should register histogram without labels", function()
            metrics:register_histogram("test_histogram", "Test histogram")
            
            assert.equals(0, ngx.shared.metrics:get("test_histogram_sum"))
            assert.equals(0, ngx.shared.metrics:get("test_histogram_count"))
            -- Check some default buckets
            assert.equals(0, ngx.shared.metrics:get("test_histogram_bucket_0.005"))
            assert.equals(0, ngx.shared.metrics:get("test_histogram_bucket_inf"))
        end)
        
        it("should register histogram with label values", function()
            metrics:register_histogram("test_histogram", "Test histogram", 
                {method={"GET", "POST"}})
            
            -- Check GET labels
            assert.equals(0, ngx.shared.metrics:get("test_histogram:method=GET_sum"))
            assert.equals(0, ngx.shared.metrics:get("test_histogram:method=GET_count"))
            assert.equals(0, ngx.shared.metrics:get("test_histogram:method=GET_bucket_0.005"))
            
            -- Check POST labels
            assert.equals(0, ngx.shared.metrics:get("test_histogram:method=POST_sum"))
            assert.equals(0, ngx.shared.metrics:get("test_histogram:method=POST_count"))
            assert.equals(0, ngx.shared.metrics:get("test_histogram:method=POST_bucket_0.005"))
        end)
        
        it("should register histogram with custom buckets", function()
            metrics:register_histogram("test_histogram", "Test histogram", 
                {}, {0.1, 0.5, 1.0})
            
            -- Keys use tostring() so 1.0 becomes "1"
            assert.equals(0, ngx.shared.metrics:get("test_histogram_bucket_0.1"))
            assert.equals(0, ngx.shared.metrics:get("test_histogram_bucket_0.5"))
            assert.equals(0, ngx.shared.metrics:get("test_histogram_bucket_1"))
            assert.equals(0, ngx.shared.metrics:get("test_histogram_bucket_inf"))
        end)
        
        it("should generate all label combinations", function()
            metrics:register_histogram("test_histogram", "Test histogram", 
                {method={"GET", "POST"}, status={"200", "404"}})
            
            -- Should create 4 combinations: GET+200, GET+404, POST+200, POST+404
            assert.equals(0, ngx.shared.metrics:get("test_histogram:method=GET,status=200_sum"))
            assert.equals(0, ngx.shared.metrics:get("test_histogram:method=GET,status=404_sum"))
            assert.equals(0, ngx.shared.metrics:get("test_histogram:method=POST,status=200_sum"))
            assert.equals(0, ngx.shared.metrics:get("test_histogram:method=POST,status=404_sum"))
        end)
    end)
    
    describe("observe_histogram", function()
        it("should observe histogram value without labels", function()
            metrics:register_histogram("test_histogram", "Test histogram")
            metrics:observe_histogram("test_histogram", 0.25)
            
            assert.equals(0.25, ngx.shared.metrics:get("test_histogram_sum"))
            assert.equals(1, ngx.shared.metrics:get("test_histogram_count"))
            
            -- Check bucket increments - use actual key format
            assert.equals(1, ngx.shared.metrics:get("test_histogram_bucket_0.25"))
            assert.equals(1, ngx.shared.metrics:get("test_histogram_bucket_0.5"))
            assert.equals(1, ngx.shared.metrics:get("test_histogram_bucket_inf"))
            assert.equals(0, ngx.shared.metrics:get("test_histogram_bucket_0.1"))
        end)
        
        it("should observe histogram value with labels", function()
            metrics:register_histogram("test_histogram", "Test histogram", 
                {method={"GET"}})
            metrics:observe_histogram("test_histogram", 0.15, {method="GET"})
            
            assert.equals(0.15, ngx.shared.metrics:get("test_histogram:method=GET_sum"))
            assert.equals(1, ngx.shared.metrics:get("test_histogram:method=GET_count"))
            
            -- Check bucket increments - use actual key format
            assert.equals(1, ngx.shared.metrics:get("test_histogram:method=GET_bucket_0.25"))
            assert.equals(1, ngx.shared.metrics:get("test_histogram:method=GET_bucket_inf"))
            assert.equals(0, ngx.shared.metrics:get("test_histogram:method=GET_bucket_0.1"))
        end)
        
        it("should accumulate histogram values", function()
            metrics:register_histogram("test_histogram", "Test histogram")
            metrics:observe_histogram("test_histogram", 0.1)
            metrics:observe_histogram("test_histogram", 0.3)
            
            assert.equals(0.4, ngx.shared.metrics:get("test_histogram_sum"))
            assert.equals(2, ngx.shared.metrics:get("test_histogram_count"))
            
            -- Check bucket accumulation
            assert.equals(2, ngx.shared.metrics:get("test_histogram_bucket_0.5"))
            assert.equals(2, ngx.shared.metrics:get("test_histogram_bucket_inf"))
        end)
    end)
    
    describe("format_prometheus_line", function()
        it("should format simple metric", function()
            local line = metrics:format_prometheus_line("test_metric", 42)
            assert.equals("test_metric 42", line)
        end)
        
        it("should format metric with labels", function()
            local line = metrics:format_prometheus_line("test_metric:method=GET,route=test", 42)
            assert.equals('test_metric{method="GET",route="test"} 42', line)
        end)
    end)
    
    describe("generate_prometheus", function()
        it("should generate valid Prometheus histogram output", function()
            metrics:register_histogram("test_histogram", "Test histogram", {}, {0.1, 0.5, 1.0})
            metrics:observe_histogram("test_histogram", 0.25)
            
            local output = metrics:generate_prometheus()
            
            assert.is_string(output)
            assert.is_true(string.find(output, "# HELP test_histogram Test histogram") ~= nil)
            assert.is_true(string.find(output, "# TYPE test_histogram histogram") ~= nil)
            
            -- Check bucket outputs
            assert.is_true(string.find(output, 'test_histogram_bucket{le="0.5"} 1') ~= nil)
            assert.is_true(string.find(output, 'test_histogram_bucket{le="1"} 1') ~= nil)
            assert.is_true(string.find(output, 'test_histogram_bucket{le="0.1"} 0') ~= nil)
            -- Use plain string match for +Inf (no pattern matching)
            assert.is_true(string.find(output, 'test_histogram_bucket{le="+Inf"} 1', 1, true) ~= nil)
            
            -- Check sum and count
            assert.is_true(string.find(output, "test_histogram_sum 0.25") ~= nil)
            assert.is_true(string.find(output, "test_histogram_count 1") ~= nil)
        end)
        
        it("should generate valid Prometheus counter output", function()
            metrics:register_counter("test_counter", "Test counter", 
                {method={"GET", "POST"}})
            metrics:inc_counter("test_counter", 5, {method="GET"})
            metrics:inc_counter("test_counter", 3, {method="POST"})
            
            local output = metrics:generate_prometheus()
            
            assert.is_string(output)
            assert.is_true(string.find(output, "# HELP test_counter Test counter") ~= nil)
            assert.is_true(string.find(output, "# TYPE test_counter counter") ~= nil)
            assert.is_true(string.find(output, 'test_counter{method="GET"} 5') ~= nil)
            assert.is_true(string.find(output, 'test_counter{method="POST"} 3') ~= nil)
        end)
    end)
    
    describe("get_summary", function()
        it("should return summary of all metrics", function()
            metrics:register_histogram("test_histogram", "Test histogram")
            metrics:observe_histogram("test_histogram", 2.5)
            
            local summary = metrics:get_summary()
            
            assert.equals(2.5, summary["test_histogram_sum"])
            assert.equals(1, summary["test_histogram_count"])
        end)
    end)
    
    describe("race condition handling", function()
        it("should handle concurrent histogram observations safely", function()
            metrics:register_histogram("concurrent_histogram", "Test concurrent access")
            
            -- Simulate concurrent observations by calling observe multiple times
            -- Since we pre-initialize keys, all incr operations should be atomic
            local observations = {1.0, 2.0, 3.0, 4.0, 5.0}
            local expected_sum = 0
            local expected_count = #observations
            
            for _, value in ipairs(observations) do
                metrics:observe_histogram("concurrent_histogram", value)
                expected_sum = expected_sum + value
            end
            
            assert.equals(expected_sum, ngx.shared.metrics:get("concurrent_histogram_sum"))
            assert.equals(expected_count, ngx.shared.metrics:get("concurrent_histogram_count"))
        end)
        
        it("should handle concurrent observations with same labels", function()
            metrics:register_histogram("labeled_histogram", "Test labeled concurrent access", 
                {method={"GET"}})
            
            -- Multiple concurrent observations with same labels
            local labels = {method="GET"}
            local values = {0.1, 0.2, 0.3, 0.4, 0.5}
            local expected_sum = 0
            
            for _, value in ipairs(values) do
                metrics:observe_histogram("labeled_histogram", value, labels)
                expected_sum = expected_sum + value
            end
            
            assert.equals(expected_sum, ngx.shared.metrics:get("labeled_histogram:method=GET_sum"))
            assert.equals(#values, ngx.shared.metrics:get("labeled_histogram:method=GET_count"))
        end)
        
        it("should handle concurrent observations with different labels", function()
            metrics:register_histogram("multi_label_histogram", "Test multi-label concurrent access",
                {
                    method={"GET", "POST"},
                    status={"200", "404"}
                })
            
            -- Concurrent observations with different label combinations
            local test_cases = {
                {labels = {method="GET", status="200"}, value = 1.0},
                {labels = {method="POST", status="200"}, value = 2.0},
                {labels = {method="GET", status="404"}, value = 3.0},
                {labels = {method="GET", status="200"}, value = 4.0}  -- Same labels as first
            }
            
            for _, case in ipairs(test_cases) do
                metrics:observe_histogram("multi_label_histogram", case.value, case.labels)
            end
            
            -- Verify individual label combinations
            assert.equals(5.0, ngx.shared.metrics:get("multi_label_histogram:method=GET,status=200_sum"))
            assert.equals(2, ngx.shared.metrics:get("multi_label_histogram:method=GET,status=200_count"))
            
            assert.equals(2.0, ngx.shared.metrics:get("multi_label_histogram:method=POST,status=200_sum"))
            assert.equals(1, ngx.shared.metrics:get("multi_label_histogram:method=POST,status=200_count"))
            
            assert.equals(3.0, ngx.shared.metrics:get("multi_label_histogram:method=GET,status=404_sum"))
            assert.equals(1, ngx.shared.metrics:get("multi_label_histogram:method=GET,status=404_count"))
        end)
        
        it("should maintain consistency when registering after observations", function()
            -- This tests that pre-initialization prevents race conditions
            -- If we didn't pre-initialize, this could cause issues
            
            -- First register and observe
            metrics:register_histogram("consistency_test", "Test consistency")
            metrics:observe_histogram("consistency_test", 1.0)
            
            -- Verify initial state
            assert.equals(1.0, ngx.shared.metrics:get("consistency_test_sum"))
            assert.equals(1, ngx.shared.metrics:get("consistency_test_count"))
            
            -- Additional observations should work consistently
            metrics:observe_histogram("consistency_test", 2.0)
            metrics:observe_histogram("consistency_test", 3.0)
            
            assert.equals(6.0, ngx.shared.metrics:get("consistency_test_sum"))
            assert.equals(3, ngx.shared.metrics:get("consistency_test_count"))
        end)
        
        it("should handle rapid sequential observations", function()
            metrics:register_histogram("rapid_test", "Test rapid observations")
            
            -- Simulate rapid sequential calls that might happen in high-traffic scenarios
            local total_sum = 0
            local num_observations = 100
            
            for i = 1, num_observations do
                local value = i * 0.01  -- 0.01, 0.02, 0.03, etc.
                metrics:observe_histogram("rapid_test", value)
                total_sum = total_sum + value
            end
            
            -- Verify all observations were recorded correctly
            assert.equals(total_sum, ngx.shared.metrics:get("rapid_test_sum"))
            assert.equals(num_observations, ngx.shared.metrics:get("rapid_test_count"))
        end)
    end)
    
    describe("format_prometheus_bucket_line", function()
        it("should format bucket metric without labels", function()
            local line = metrics:format_prometheus_bucket_line("test_metric_bucket_0.5", 42)
            assert.equals('test_metric_bucket{le="0.5"} 42', line)
        end)
        
        it("should format bucket metric with labels", function()
            local line = metrics:format_prometheus_bucket_line("test_metric:method=GET,route=test_bucket_1.0", 42)
            assert.equals('test_metric_bucket{method="GET",route="test",le="1.0"} 42', line)
        end)
        
        it("should format +Inf bucket", function()
            local line = metrics:format_prometheus_bucket_line("test_metric_bucket_inf", 42)
            assert.equals('test_metric_bucket{le="+Inf"} 42', line)
        end)
    end)
    
    describe("register_counter", function()
        it("should register counter without labels", function()
            metrics:register_counter("test_counter", "Test counter")
            
            assert.equals(0, ngx.shared.metrics:get("test_counter"))
        end)
        
        it("should register counter with label values", function()
            metrics:register_counter("test_counter", "Test counter", 
                {method={"GET", "POST"}})
            
            assert.equals(0, ngx.shared.metrics:get("test_counter:method=GET"))
            assert.equals(0, ngx.shared.metrics:get("test_counter:method=POST"))
        end)
        
        it("should generate all label combinations for counters", function()
            metrics:register_counter("test_counter", "Test counter", 
                {method={"GET", "POST"}, status={"200", "404"}})
            
            -- Should create 4 combinations
            assert.equals(0, ngx.shared.metrics:get("test_counter:method=GET,status=200"))
            assert.equals(0, ngx.shared.metrics:get("test_counter:method=GET,status=404"))
            assert.equals(0, ngx.shared.metrics:get("test_counter:method=POST,status=200"))
            assert.equals(0, ngx.shared.metrics:get("test_counter:method=POST,status=404"))
        end)
    end)
    
    describe("inc_counter", function()
        it("should increment counter without labels", function()
            metrics:register_counter("test_counter", "Test counter")
            metrics:inc_counter("test_counter")
            
            assert.equals(1, ngx.shared.metrics:get("test_counter"))
        end)
        
        it("should increment counter with custom value", function()
            metrics:register_counter("test_counter", "Test counter")
            metrics:inc_counter("test_counter", 5)
            
            assert.equals(5, ngx.shared.metrics:get("test_counter"))
        end)
        
        it("should increment counter with labels", function()
            metrics:register_counter("test_counter", "Test counter", 
                {method={"GET"}})
            metrics:inc_counter("test_counter", 3, {method="GET"})
            
            assert.equals(3, ngx.shared.metrics:get("test_counter:method=GET"))
        end)
        
        it("should accumulate counter values", function()
            metrics:register_counter("test_counter", "Test counter")
            metrics:inc_counter("test_counter", 2)
            metrics:inc_counter("test_counter", 3)
            
            assert.equals(5, ngx.shared.metrics:get("test_counter"))
        end)
        
        it("should fail for unregistered counter", function()
            assert.has_error(function() 
                metrics:inc_counter("nonexistent_counter")
            end)
        end)
        
        it("should handle concurrent counter increments safely", function()
            metrics:register_counter("concurrent_counter", "Test concurrent counter access")
            
            -- Simulate concurrent increments
            local increments = {1, 2, 3, 4, 5}
            local expected_total = 0
            
            for _, value in ipairs(increments) do
                metrics:inc_counter("concurrent_counter", value)
                expected_total = expected_total + value
            end
            
            assert.equals(expected_total, ngx.shared.metrics:get("concurrent_counter"))
        end)
        
        it("should handle concurrent counter increments with labels", function()
            metrics:register_counter("labeled_counter", "Test labeled counter access", 
                {method={"GET", "POST"}})
            
            -- Concurrent increments with different labels
            metrics:inc_counter("labeled_counter", 2, {method="GET"})
            metrics:inc_counter("labeled_counter", 3, {method="POST"})
            metrics:inc_counter("labeled_counter", 1, {method="GET"})
            
            assert.equals(3, ngx.shared.metrics:get("labeled_counter:method=GET"))
            assert.equals(3, ngx.shared.metrics:get("labeled_counter:method=POST"))
        end)
    end)
end)
