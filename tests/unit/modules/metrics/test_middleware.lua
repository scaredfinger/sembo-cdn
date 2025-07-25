local describe = require('busted').describe
local before_each = require('busted').before_each
local it = require('busted').it
local assert = require('luassert')
local stub = require('luassert.stub')
local spy = require('luassert.spy')

require "tests.test_helper"

describe('MetricsMiddleware', function()
    local MetricsMiddleware = require "modules.metrics.middleware"
    local Metrics = require "modules.metrics.index"
    local middleware
    local metrics
    local mock_request
    local mock_response
    local mock_now
    local mock_shared_dict

    before_each(function()
        reset_ngx_mocks()

        -- Mock shared dictionary
        mock_shared_dict = {
            dict = {},
            set = function(self, key, value)
                self.dict[key] = value
                return true
            end,
            get = function(self, key)
                return self.dict[key]
            end,
            incr = function(self, key, value)
                self.dict[key] = (self.dict[key] or 0) + value
                return self.dict[key]
            end,
            get_keys = function(self, max_count)
                local keys = {}
                for key, _ in pairs(self.dict) do
                    table.insert(keys, key)
                end
                return keys
            end
        }

        metrics = Metrics.new(mock_shared_dict)
        mock_now = spy.new(function() return 1000.0 end)
        middleware = MetricsMiddleware:new(metrics, "test_operation", mock_now, function() return {} end)

        mock_request = { path = "/test" }
        mock_response = { status = 200, body = "OK" }

        -- Register the histogram metric
        metrics:register_histogram("test_operation", {
            success = { "true", "false" }
        })
    end)

    describe('new', function()
        it('should create new middleware instance', function()
            assert.equals(metrics, middleware.metrics)
            assert.equals("test_operation", middleware.metric_name)
            assert.equals(mock_now, middleware.now)
        end)
    end)

    describe('execute', function()
        it('should measure execution time and observe success', function()
            local next_fn = spy.new(function() return mock_response end)

            local call_count = 0
            mock_now = function()
                call_count = call_count + 1
                if call_count == 1 then
                    return 1000.0
                else
                    return 1000.5
                end
            end
            middleware.now = mock_now

            local result = middleware:execute(mock_request, next_fn)

            assert.spy(next_fn).was_called_with(mock_request)
            assert.equals(mock_response, result)

            -- Verify success metric was observed with correct duration
            local summary = metrics:get_summary()
            assert.equals(1, summary["test_operation_count{success=\"true\"}"])
            assert.equals(0.5, summary["test_operation_sum{success=\"true\"}"])
        end)

        it('should increment failure counter when next function throws error', function()
            local next_fn = spy.new(function() error("test error") end)

            local call_count = 0
            mock_now = function()
                call_count = call_count + 1
                if call_count == 1 then
                    return 1000.0
                else
                    return 1000.2
                end
            end
            middleware.now = mock_now

            assert.has_error(function()
                middleware:execute(mock_request, next_fn)
            end)

            assert.spy(next_fn).was_called_with(mock_request)

            -- Verify failure metric was incremented
            local summary = metrics:get_summary()
            assert.equals(1, summary["test_operation_count{success=\"false\"}"])
        end)

        it('should handle zero execution time', function()
            local next_fn = spy.new(function() return mock_response end)

            mock_now = function()
                return 1000.0
            end
            middleware.now = mock_now

            local result = middleware:execute(mock_request, next_fn)

            assert.equals(mock_response, result)

            local summary = metrics:get_summary()
            assert.equals(1, summary["test_operation_count{success=\"true\"}"])
            assert.equals(0, summary["test_operation_sum{success=\"true\"}"])
        end)

        it('should handle multiple successful executions', function()
            local next_fn = spy.new(function() return mock_response end)

            local call_count = 0
            mock_now = function()
                call_count = call_count + 1
                if call_count == 1 then
                    return 1000.0
                elseif call_count == 2 then
                    return 1000.1
                elseif call_count == 3 then
                    return 2000.0
                else
                    return 2000.3
                end
            end
            middleware.now = mock_now

            middleware:execute(mock_request, next_fn)
            middleware:execute(mock_request, next_fn)

            local summary = metrics:get_summary()
            assert.equals(2, summary["test_operation_count{success=\"true\"}"])
            assert.near(0.4, summary["test_operation_sum{success=\"true\"}"], 0.0001)
        end)

        it('should handle mixed success and failure executions', function()
            local success_fn = spy.new(function() return mock_response end)
            local failure_fn = spy.new(function() error("failure") end)

            local call_count = 0
            mock_now = function()
                call_count = call_count + 1
                if call_count == 1 then
                    return 1000.0
                elseif call_count == 2 then
                    return 1000.1
                elseif call_count == 3 then
                    return 2000.0
                else
                    return 2000.2
                end
            end
            middleware.now = mock_now

            middleware:execute(mock_request, success_fn)

            assert.has_error(function()
                middleware:execute(mock_request, failure_fn)
            end)

            local summary = metrics:get_summary()
            assert.equals(1, summary["test_operation_count{success=\"true\"}"])
            assert.near(0.1, summary["test_operation_sum{success=\"true\"}"], 0.0001)
            assert.equals(1, summary["test_operation_count{success=\"false\"}"])
        end)
    end)
end)
