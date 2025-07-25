local describe = require('busted').describe
local before_each = require('busted').before_each
local it = require('busted').it
local spy = require('luassert.spy')

local assert = require('luassert')

-- Unit tests for metrics module
require "tests.test_helper" -- Load ngx mocks before requiring modules

describe('metrics module', function()
    local Metrics = require "modules.metrics.index"
    local metrics
    local log_error = spy.new(function(msg, ...)
    end)

    before_each(function()
        reset_ngx_mocks()
        metrics = Metrics.new(ngx.shared.metrics, log_error)
    end)

    describe('new', function()
        it('should create new metrics instance', function()
            assert.is_not_nil(metrics)
            assert.equals('table', type(metrics.histograms))
        end)

        it('should fail with nil metrics_dict', function()
            assert.has_error(function() Metrics.new(nil) end)
        end)
    end)

    describe('build_key', function()
        it('should build key without labels', function()
            local key = metrics:_build_key('test_metric')
            assert.equals('test_metric', key)
        end)

        it('should build key with labels', function()
            local key = metrics:_build_key('test_metric', { route = "test", method = "GET" })
            assert.equals('test_metric{method="GET",route="test"}', key)
        end)
    end)

    describe('register_histogram', function()
        it('should register histogram without labels', function()
            metrics:register_histogram('test_histogram')

            -- Success label is now added automatically
            assert.equals(0, ngx.shared.metrics:get('test_histogram_sum{success="true"}'))
            assert.equals(0, ngx.shared.metrics:get('test_histogram_count{success="true"}'))
            assert.equals(0, ngx.shared.metrics:get('test_histogram_sum{success="false"}'))
            assert.equals(0, ngx.shared.metrics:get('test_histogram_count{success="false"}'))
            -- Check some default buckets
            assert.equals(0, ngx.shared.metrics:get('test_histogram_bucket{le="0.005",success="true"}'))
            assert.equals(0, ngx.shared.metrics:get('test_histogram_bucket{le="+Inf",success="true"}'))
        end)

        it('should register histogram with label values', function()
            metrics:register_histogram('test_histogram', { method = { "GET", "POST" } })

            -- Check GET labels (success is automatically added)
            assert.equals(0, ngx.shared.metrics:get('test_histogram_sum{method="GET",success="true"}'))
            assert.equals(0, ngx.shared.metrics:get('test_histogram_count{method="GET",success="true"}'))
            assert.equals(0, ngx.shared.metrics:get('test_histogram_bucket{le="0.005",method="GET",success="true"}'))

            -- Check POST labels
            assert.equals(0, ngx.shared.metrics:get('test_histogram_sum{method="POST",success="true"}'))
            assert.equals(0, ngx.shared.metrics:get('test_histogram_count{method="POST",success="true"}'))
            assert.equals(0, ngx.shared.metrics:get('test_histogram_bucket{le="0.005",method="POST",success="true"}'))
        end)

        it('should register histogram with custom buckets', function()
            metrics:register_histogram('test_histogram',
                {}, { 0.1, 0.5, 1.0 })

            -- Keys use tostring() so 1.0 becomes "1", success is added automatically
            assert.equals(0, ngx.shared.metrics:get('test_histogram_bucket{le="0.1",success="true"}'))
            assert.equals(0, ngx.shared.metrics:get('test_histogram_bucket{le="0.5",success="true"}'))
            assert.equals(0, ngx.shared.metrics:get('test_histogram_bucket{le="1",success="true"}'))
            assert.equals(0, ngx.shared.metrics:get('test_histogram_bucket{le="+Inf",success="true"}'))
        end)

        it('should generate all label combinations', function()
            metrics:register_histogram('test_histogram', { method = { "GET", "POST" }, status = { "200", "404" } })

            -- Should create 8 combinations: (GET,POST) x (200,404) x (true,false)
            assert.equals(0, ngx.shared.metrics:get('test_histogram_sum{method="GET",status="200",success="true"}'))
            assert.equals(0, ngx.shared.metrics:get('test_histogram_sum{method="GET",status="404",success="true"}'))
            assert.equals(0, ngx.shared.metrics:get('test_histogram_sum{method="POST",status="200",success="true"}'))
            assert.equals(0, ngx.shared.metrics:get('test_histogram_sum{method="POST",status="404",success="true"}'))
            assert.equals(0, ngx.shared.metrics:get('test_histogram_sum{method="GET",status="200",success="false"}'))
            assert.equals(0, ngx.shared.metrics:get('test_histogram_sum{method="GET",status="404",success="false"}'))
            assert.equals(0, ngx.shared.metrics:get('test_histogram_sum{method="POST",status="200",success="false"}'))
            assert.equals(0, ngx.shared.metrics:get('test_histogram_sum{method="POST",status="404",success="false"}'))
        end)
    end)

    describe('_observe_histogram (private)', function()
        it('should observe histogram value without labels', function()
            metrics:register_histogram('test_histogram')
            metrics:_observe_histogram('test_histogram', 0.25, { success = "true" })

            assert.equals(0.25, ngx.shared.metrics:get('test_histogram_sum{success="true"}'))
            assert.equals(1, ngx.shared.metrics:get('test_histogram_count{success="true"}'))

            -- Check bucket increments - use actual key format
            assert.equals(1, ngx.shared.metrics:get('test_histogram_bucket{le="0.25",success="true"}'))
            assert.equals(1, ngx.shared.metrics:get('test_histogram_bucket{le="0.5",success="true"}'))
            assert.equals(1, ngx.shared.metrics:get('test_histogram_bucket{le="+Inf",success="true"}'))
            assert.equals(0, ngx.shared.metrics:get('test_histogram_bucket{le="0.1",success="true"}'))
        end)

        it('should observe histogram value with labels', function()
            metrics:register_histogram('test_histogram',
                { method = { "GET" } })
            metrics:_observe_histogram('test_histogram', 0.15, { method = "GET", success = "true" })

            assert.equals(0.15, ngx.shared.metrics:get('test_histogram_sum{method="GET",success="true"}'))
            assert.equals(1, ngx.shared.metrics:get('test_histogram_count{method="GET",success="true"}'))

            -- Check bucket increments - use actual key format
            assert.equals(1, ngx.shared.metrics:get('test_histogram_bucket{le="0.25",method="GET",success="true"}'))
            assert.equals(1, ngx.shared.metrics:get('test_histogram_bucket{le="+Inf",method="GET",success="true"}'))
            assert.equals(0, ngx.shared.metrics:get('test_histogram_bucket{le="0.1",method="GET",success="true"}'))
        end)

        it('should accumulate histogram values', function()
            metrics:register_histogram('test_histogram')
            metrics:_observe_histogram('test_histogram', 0.1, { success = "true" })
            metrics:_observe_histogram('test_histogram', 0.3, { success = "true" })

            assert.equals(0.4, ngx.shared.metrics:get('test_histogram_sum{success="true"}'))
            assert.equals(2, ngx.shared.metrics:get('test_histogram_count{success="true"}'))

            -- Check bucket accumulation
            assert.equals(2, ngx.shared.metrics:get('test_histogram_bucket{le="0.5",success="true"}'))
            assert.equals(2, ngx.shared.metrics:get('test_histogram_bucket{le="+Inf",success="true"}'))
        end)
    end)

    describe('format_prometheus_line', function()
        it('should format simple metric', function()
            local line = metrics:_format_prometheus_line('test_metric', 42)
            assert.equals('test_metric 42', line)
        end)

        it('should format metric with labels', function()
            local line = metrics:_format_prometheus_line('test_metric{method="GET",route="test"}', 42)
            assert.equals('test_metric{method="GET",route="test"} 42', line)
        end)
    end)

    describe('generate_prometheus', function()
        it('should generate valid Prometheus histogram output', function()
            metrics:register_histogram('test_histogram', {}, { 0.1, 0.5, 1.0 })
            metrics:_observe_histogram('test_histogram', 0.25, { success = "true" })

            local output = metrics:generate_prometheus()

            assert.is_string(output)
            assert.is_true(string.find(output, '# HELP test_histogram ') ~= nil)
            assert.is_true(string.find(output, '# TYPE test_histogram histogram') ~= nil)

            -- Check bucket outputs
            assert.is_true(string.find(output, 'test_histogram_bucket{le="0.5",success="true"} 1') ~= nil)
            assert.is_true(string.find(output, 'test_histogram_bucket{le="1",success="true"} 1') ~= nil)
            assert.is_true(string.find(output, 'test_histogram_bucket{le="0.1",success="true"} 0') ~= nil)
            -- Use plain string match for +Inf (no pattern matching)
            assert.is_true(string.find(output, 'test_histogram_bucket{le="+Inf",success="true"} 1', 1, true) ~= nil)

            -- Check sum and count
            assert.is_true(string.find(output, 'test_histogram_sum{success="true"} 0.25') ~= nil)
            assert.is_true(string.find(output, 'test_histogram_count{success="true"} 1') ~= nil)
        end)

        it('should generate valid Prometheus counter output', function()
            metrics:register_counter('test_counter',
                { method = { "GET", "POST" } })
            metrics:inc_counter('test_counter', 5, { method = "GET" })
            metrics:inc_counter('test_counter', 3, { method = "POST" })

            local output = metrics:generate_prometheus()

            assert.is_string(output)
            assert.is_true(string.find(output, '# HELP test_counter ') ~= nil)
            assert.is_true(string.find(output, '# TYPE test_counter counter') ~= nil)
            assert.is_true(string.find(output, 'test_counter{method="GET"} 5') ~= nil)
            assert.is_true(string.find(output, 'test_counter{method="POST"} 3') ~= nil)
        end)
    end)

    describe('get_summary', function()
        it('should return summary of all metrics', function()
            metrics:register_histogram('test_histogram')
            metrics:_observe_histogram('test_histogram', 2.5, { success = "true" })

            local summary = metrics:get_summary()

            assert.equals(2.5, summary["test_histogram_sum{success=\"true\"}"])
            assert.equals(1, summary["test_histogram_count{success=\"true\"}"])
        end)
    end)

    describe('race condition handling', function()
        it('should handle concurrent histogram observations safely', function()
            metrics:register_histogram('concurrent_histogram')

            -- Simulate concurrent observations by calling observe multiple times
            -- Since we pre-initialize keys, all incr operations should be atomic
            local observations = { 1.0, 2.0, 3.0, 4.0, 5.0 }
            local expected_sum = 0
            local expected_count = #observations

            for _, value in ipairs(observations) do
                metrics:_observe_histogram('concurrent_histogram', value, { success = "true" })
                expected_sum = expected_sum + value
            end

            assert.equals(expected_sum, ngx.shared.metrics:get('concurrent_histogram_sum{success="true"}'))
            assert.equals(expected_count, ngx.shared.metrics:get('concurrent_histogram_count{success="true"}'))
        end)

        it('should handle concurrent observations with same labels', function()
            metrics:register_histogram('labeled_histogram',
                { method = { "GET" } })

            -- Multiple concurrent observations with same labels
            local labels = { method = "GET", success = "true" }
            local values = { 0.1, 0.2, 0.3, 0.4, 0.5 }
            local expected_sum = 0

            for _, value in ipairs(values) do
                metrics:_observe_histogram('labeled_histogram', value, labels)
                expected_sum = expected_sum + value
            end

            assert.equals(expected_sum, ngx.shared.metrics:get('labeled_histogram_sum{method="GET",success="true"}'))
            assert.equals(#values, ngx.shared.metrics:get('labeled_histogram_count{method="GET",success="true"}'))
        end)

        it('should handle concurrent observations with different labels', function()
            metrics:register_histogram('multi_label_histogram',
                {
                    method = { "GET", "POST" },
                    status = { "200", "404" }
                })

            -- Concurrent observations with different label combinations
            local test_cases = {
                { labels = { method = "GET", status = "200", success = "true" }, value = 1.0 },
                { labels = { method = "POST", status = "200", success = "true" }, value = 2.0 },
                { labels = { method = "GET", status = "404", success = "false" }, value = 3.0 },
                { labels = { method = "GET", status = "200", success = "true" }, value = 4.0 } -- Same labels as first
            }

            for _, case in ipairs(test_cases) do
                metrics:_observe_histogram('multi_label_histogram', case.value, case.labels)
            end

            -- Verify individual label combinations
            assert.equals(5.0, ngx.shared.metrics:get('multi_label_histogram_sum{method="GET",status="200",success="true"}'))
            assert.equals(2, ngx.shared.metrics:get('multi_label_histogram_count{method="GET",status="200",success="true"}'))

            assert.equals(2.0, ngx.shared.metrics:get('multi_label_histogram_sum{method="POST",status="200",success="true"}'))
            assert.equals(1, ngx.shared.metrics:get('multi_label_histogram_count{method="POST",status="200",success="true"}'))

            assert.equals(3.0, ngx.shared.metrics:get('multi_label_histogram_sum{method="GET",status="404",success="false"}'))
            assert.equals(1, ngx.shared.metrics:get('multi_label_histogram_count{method="GET",status="404",success="false"}'))
        end)

        it('should maintain consistency when registering after observations', function()
            -- This tests that pre-initialization prevents race conditions
            -- If we didn't pre-initialize, this could cause issues

            -- First register and observe
            metrics:register_histogram('consistency_test')
            metrics:_observe_histogram('consistency_test', 1.0, { success = "true" })

            -- Verify initial state
            assert.equals(1.0, ngx.shared.metrics:get('consistency_test_sum{success="true"}'))
            assert.equals(1, ngx.shared.metrics:get('consistency_test_count{success="true"}'))

            -- Additional observations should work consistently
            metrics:_observe_histogram('consistency_test', 2.0, { success = "true" })
            metrics:_observe_histogram('consistency_test', 3.0, { success = "true" })

            assert.equals(6.0, ngx.shared.metrics:get('consistency_test_sum{success="true"}'))
            assert.equals(3, ngx.shared.metrics:get('consistency_test_count{success="true"}'))
        end)

        it('should handle rapid sequential observations', function()
            metrics:register_histogram('rapid_test')

            -- Simulate rapid sequential calls that might happen in high-traffic scenarios
            local total_sum = 0
            local num_observations = 100

            for i = 1, num_observations do
                local value = i * 0.01 -- 0.01, 0.02, 0.03, etc.
                metrics:_observe_histogram('rapid_test', value, { success = "true" })
                total_sum = total_sum + value
            end

            -- Verify all observations were recorded correctly
            assert.equals(total_sum, ngx.shared.metrics:get('rapid_test_sum{success="true"}'))
            assert.equals(num_observations, ngx.shared.metrics:get('rapid_test_count{success="true"}'))
        end)
    end)

    describe('register_counter', function()
        it('should register counter without labels', function()
            metrics:register_counter('test_counter')

            assert.equals(0, ngx.shared.metrics:get('test_counter'))
        end)

        it('should register counter with label values', function()
            metrics:register_counter('test_counter',
                { method = { "GET", "POST" } })

            assert.equals(0, ngx.shared.metrics:get('test_counter{method="GET"}'))
            assert.equals(0, ngx.shared.metrics:get('test_counter{method="POST"}'))
        end)

        it('should generate all label combinations for counters', function()
            metrics:register_counter('test_counter',
                { method = { "GET", "POST" }, status = { "200", "404" } })

            -- Should create 4 combinations
            assert.equals(0, ngx.shared.metrics:get('test_counter{method="GET",status="200"}'))
            assert.equals(0, ngx.shared.metrics:get('test_counter{method="GET",status="404"}'))
            assert.equals(0, ngx.shared.metrics:get('test_counter{method="POST",status="200"}'))
            assert.equals(0, ngx.shared.metrics:get('test_counter{method="POST",status="404"}'))
        end)
    end)

    describe('inc_counter', function()
        it('should increment counter without labels', function()
            metrics:register_counter('test_counter')
            metrics:inc_counter('test_counter')

            assert.equals(1, ngx.shared.metrics:get('test_counter'))
        end)

        it('should increment counter with custom value', function()
            metrics:register_counter('test_counter')
            metrics:inc_counter('test_counter', 5)

            assert.equals(5, ngx.shared.metrics:get('test_counter'))
        end)

        it('should increment counter with labels', function()
            metrics:register_counter('test_counter',
                { method = { "GET" } })
            metrics:inc_counter('test_counter', 3, { method = "GET" })

            assert.equals(3, ngx.shared.metrics:get('test_counter{method="GET"}'))
        end)

        it('should accumulate counter values', function()
            metrics:register_counter('test_counter')
            metrics:inc_counter('test_counter', 2)
            metrics:inc_counter('test_counter', 3)

            assert.equals(5, ngx.shared.metrics:get('test_counter'))
        end)

        it('should fail for unregistered counter', function()
            metrics:inc_counter('nonexistent_counter')

            assert.spy(log_error).was_called()
        end)

        it('should handle concurrent counter increments safely', function()
            metrics:register_counter('concurrent_counter')

            -- Simulate concurrent increments
            local increments = { 1, 2, 3, 4, 5 }
            local expected_total = 0

            for _, value in ipairs(increments) do
                metrics:inc_counter('concurrent_counter', value)
                expected_total = expected_total + value
            end

            assert.equals(expected_total, ngx.shared.metrics:get('concurrent_counter'))
        end)

        it('should handle concurrent counter increments with labels', function()
            metrics:register_counter('labeled_counter',
                { method = { "GET", "POST" } })

            -- Concurrent increments with different labels
            metrics:inc_counter('labeled_counter', 2, { method = "GET" })
            metrics:inc_counter('labeled_counter', 3, { method = "POST" })
            metrics:inc_counter('labeled_counter', 1, { method = "GET" })

            assert.equals(3, ngx.shared.metrics:get('labeled_counter{method="GET"}'))
            assert.equals(3, ngx.shared.metrics:get('labeled_counter{method="POST"}'))
        end)
    end)

    describe('register_histogram_with_success_label', function()
        it('should register histogram with success label automatically', function()
            metrics:register_histogram("test_request", {
                method = { "GET", "POST" }
            }, { 0.1, 0.5, 1.0 })

            -- Check labeled metrics (success label is added automatically)
            assert.equals(0, ngx.shared.metrics:get('test_request_sum{method="GET",success="true"}'))
            assert.equals(0, ngx.shared.metrics:get('test_request_count{method="GET",success="true"}'))
            assert.equals(0, ngx.shared.metrics:get('test_request_sum{method="GET",success="false"}'))
            assert.equals(0, ngx.shared.metrics:get('test_request_sum{method="POST",success="true"}'))
            assert.equals(0, ngx.shared.metrics:get('test_request_sum{method="POST",success="false"}'))
        end)

        it('should handle empty label_values in histogram config', function()
            metrics:register_histogram("empty_labels_test")

            -- Success label is added automatically even with empty labels
            assert.equals(0, ngx.shared.metrics:get('empty_labels_test_sum{success="true"}'))
            assert.equals(0, ngx.shared.metrics:get('empty_labels_test_sum{success="false"}'))
        end)
    end)

    describe('observe_histogram_success', function()
        it('should observe histogram success without labels', function()
            metrics:register_histogram("test_request")
            metrics:observe_histogram_success('test_request', 0.25)

            assert.equals(0.25, ngx.shared.metrics:get('test_request_sum{success="true"}'))
            assert.equals(1, ngx.shared.metrics:get('test_request_count{success="true"}'))
        end)

        it('should observe histogram success with labels', function()
            metrics:register_histogram("test_request", {
                method = { "GET" }
            })
            metrics:observe_histogram_success('test_request', 0.15, { method = "GET" })

            assert.equals(0.15, ngx.shared.metrics:get('test_request_sum{method="GET",success="true"}'))
            assert.equals(1, ngx.shared.metrics:get('test_request_count{method="GET",success="true"}'))
        end)
    end)

    describe('observe_histogram_failure', function()
        it('should observe histogram failure without labels', function()
            metrics:register_histogram("test_request")
            metrics:observe_histogram_failure('test_request', 0.35)

            assert.equals(0.35, ngx.shared.metrics:get('test_request_sum{success="false"}'))
            assert.equals(1, ngx.shared.metrics:get('test_request_count{success="false"}'))
        end)

        it('should observe histogram failure with labels', function()
            metrics:register_histogram("test_request", {
                method = { "GET" }
            })
            metrics:observe_histogram_failure('test_request', 0.25, { method = "GET" })

            assert.equals(0.25, ngx.shared.metrics:get('test_request_sum{method="GET",success="false"}'))
            assert.equals(1, ngx.shared.metrics:get('test_request_count{method="GET",success="false"}'))
        end)
    end)

    describe('register_gauge', function()
        it('should register gauge without labels', function()
            metrics:register_gauge('test_gauge')

            assert.equals(0, ngx.shared.metrics:get('test_gauge'))
        end)

        it('should register gauge with label values', function()
            metrics:register_gauge('test_gauge',
                { instance = { "server1", "server2" } })

            assert.equals(0, ngx.shared.metrics:get('test_gauge{instance="server1"}'))
            assert.equals(0, ngx.shared.metrics:get('test_gauge{instance="server2"}'))
        end)

        it('should generate all label combinations for gauges', function()
            metrics:register_gauge('test_gauge',
                { instance = { "server1", "server2" }, region = { "us", "eu" } })

            assert.equals(0, ngx.shared.metrics:get('test_gauge{instance="server1",region="us"}'))
            assert.equals(0, ngx.shared.metrics:get('test_gauge{instance="server1",region="eu"}'))
            assert.equals(0, ngx.shared.metrics:get('test_gauge{instance="server2",region="us"}'))
            assert.equals(0, ngx.shared.metrics:get('test_gauge{instance="server2",region="eu"}'))
        end)

        it('should not register gauge twice', function()
            metrics:register_gauge('test_gauge')
            metrics:register_gauge('test_gauge')

            assert.equals(0, ngx.shared.metrics:get('test_gauge'))
        end)
    end)

    describe('set_gauge', function()
        it('should set gauge without labels', function()
            metrics:register_gauge('test_gauge')
            metrics:set_gauge('test_gauge', 42.5)

            assert.equals(42.5, ngx.shared.metrics:get('test_gauge'))
        end)

        it('should set gauge with labels', function()
            metrics:register_gauge('test_gauge',
                { instance = { "server1" } })
            metrics:set_gauge('test_gauge', 15.3, { instance = "server1" })

            assert.equals(15.3, ngx.shared.metrics:get('test_gauge{instance="server1"}'))
        end)

        it('should overwrite previous gauge value', function()
            metrics:register_gauge('test_gauge')
            metrics:set_gauge('test_gauge', 10.0)
            metrics:set_gauge('test_gauge', 20.0)

            assert.equals(20.0, ngx.shared.metrics:get('test_gauge'))
        end)
    end)

    describe('inc_gauge', function()
        it('should increment gauge without labels', function()
            metrics:register_gauge('test_gauge')
            metrics:inc_gauge('test_gauge')

            assert.equals(1, ngx.shared.metrics:get('test_gauge'))
        end)

        it('should increment gauge with custom value', function()
            metrics:register_gauge('test_gauge')
            metrics:inc_gauge('test_gauge', 5.5)

            assert.equals(5.5, ngx.shared.metrics:get('test_gauge'))
        end)

        it('should increment gauge with labels', function()
            metrics:register_gauge('test_gauge',
                { instance = { "server1" } })
            metrics:inc_gauge('test_gauge', 3.2, { instance = "server1" })

            assert.equals(3.2, ngx.shared.metrics:get('test_gauge{instance="server1"}'))
        end)

        it('should accumulate increments', function()
            metrics:register_gauge('test_gauge')
            metrics:inc_gauge('test_gauge', 10)
            metrics:inc_gauge('test_gauge', 5)

            assert.equals(15, ngx.shared.metrics:get('test_gauge'))
        end)
    end)

    describe('dec_gauge', function()
        it('should decrement gauge without labels', function()
            metrics:register_gauge('test_gauge')
            metrics:set_gauge('test_gauge', 10)
            metrics:dec_gauge('test_gauge')

            assert.equals(9, ngx.shared.metrics:get('test_gauge'))
        end)

        it('should decrement gauge with custom value', function()
            metrics:register_gauge('test_gauge')
            metrics:set_gauge('test_gauge', 20)
            metrics:dec_gauge('test_gauge', 5.5)

            assert.equals(14.5, ngx.shared.metrics:get('test_gauge'))
        end)

        it('should decrement gauge with labels', function()
            metrics:register_gauge('test_gauge',
                { instance = { "server1" } })
            metrics:set_gauge('test_gauge', 100, { instance = "server1" })
            metrics:dec_gauge('test_gauge', 25, { instance = "server1" })

            assert.equals(75, ngx.shared.metrics:get('test_gauge{instance="server1"}'))
        end)

        it('should allow gauge to go negative', function()
            metrics:register_gauge('test_gauge')
            metrics:dec_gauge('test_gauge', 5)

            assert.equals(-5, ngx.shared.metrics:get('test_gauge'))
        end)
    end)

    describe('prometheus generation with gauges', function()
        it('should generate valid Prometheus gauge output', function()
            metrics:register_gauge('test_gauge',
                { instance = { "server1", "server2" } })
            metrics:set_gauge('test_gauge', 42.5, { instance = "server1" })
            metrics:set_gauge('test_gauge', 15.3, { instance = "server2" })

            local output = metrics:generate_prometheus()

            assert.is_string(output)
            assert.is_true(string.find(output, '# HELP test_gauge ') ~= nil)
            assert.is_true(string.find(output, '# TYPE test_gauge gauge') ~= nil)
            assert.is_true(string.find(output, 'test_gauge{instance="server1"} 42.5') ~= nil)
            assert.is_true(string.find(output, 'test_gauge{instance="server2"} 15.3') ~= nil)
        end)

        it('should include all metric types in prometheus output', function()
            metrics:register_counter('test_counter')
            metrics:register_gauge('test_gauge')
            metrics:register_histogram('test_histogram')

            metrics:inc_counter('test_counter', 10)
            metrics:set_gauge('test_gauge', 25.5)
            metrics:observe_histogram_success('test_histogram', 0.5)

            local output = metrics:generate_prometheus()

            assert.is_true(string.find(output, '# TYPE test_counter counter') ~= nil)
            assert.is_true(string.find(output, '# TYPE test_gauge gauge') ~= nil)
            assert.is_true(string.find(output, '# TYPE test_histogram histogram') ~= nil)
        end)
    end)
end)
