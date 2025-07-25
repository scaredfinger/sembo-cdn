local describe = require('busted').describe
local before_each = require('busted').before_each
local it = require('busted').it
local assert = require('luassert')

local CacheStorageMetricsDecorator = require("modules.cache.providers.cache_storage_metrics_decorator")

describe("CacheStorageMetricsDecorator", function()
    local mock_inner
    local mock_metrics
    local mock_now
    local decorator
    local current_time

    before_each(function()
        current_time = 1000.0

        mock_inner = {
            stored_data = {},
            get = function(self, key) return self.stored_data[key] end,
            set = function(self, key, value, tts, ttl)
                self.stored_data[key] = value
                return true
            end,
            del = function(self, key)
                self.stored_data[key] = nil
                return true
            end
        }

        mock_metrics = {
            histogram_observations = {},
            observe_histogram_success = function(self, name, duration, labels)
                table.insert(self.histogram_observations, {
                    type = "success",
                    name = name,
                    duration = duration,
                    labels = labels
                })
            end,
            observe_histogram_failure = function(self, name, duration, labels)
                table.insert(self.histogram_observations, {
                    type = "failure",
                    name = name,
                    duration = duration,
                    labels = labels
                })
            end,
            measure_execution = function(self, histogram_name, labels, func, ...)
                local start_time = current_time
                
                local success, result = pcall(func, ...)
                
                local end_time = current_time + 10.0  -- Always add 10.0 for the timing overhead
                local duration = end_time - start_time
                current_time = end_time
                
                if success then
                    self:observe_histogram_success(histogram_name, duration, labels)
                    return result
                else
                    self:observe_histogram_failure(histogram_name, duration, labels)
                    error(result)
                end
            end
        }

        mock_now = function()
            current_time = current_time + 10.0
            return current_time
        end

        decorator = CacheStorageMetricsDecorator:new(
            mock_inner,
            mock_metrics,
            "cache_operation_duration_seconds",
            "redis"
        )
    end)

    describe("new", function()
        it("should create decorator with provided cache storage", function()
            assert.are.equal(mock_inner, decorator.inner)
        end)

        it("should use provided metrics instance", function()
            assert.are.equal(mock_metrics, decorator.metrics)
        end)

        it("should use provided metrics name", function()
            assert.are.equal("cache_operation_duration_seconds", decorator.metrics_name)
        end)

        it("should use provided cache name", function()
            assert.are.equal("redis", decorator.cache_name)
        end)
    end)

    describe("get", function()
        it("should return nil when decorated storage returns nil", function()
            mock_inner.get = function(self, key) return nil end

            local result = decorator:get("test_key")

            assert.is_nil(result)
        end)

        it("should return value when decorated storage returns data", function()
            local test_value = "test_value"
            mock_inner.stored_data["test_key"] = test_value

            local result = decorator:get("test_key")

            assert.are.equal(test_value, result)
        end)

        it("should record success metrics for successful get", function()
            mock_inner.stored_data["test_key"] = "test_value"

            decorator:get("test_key")

            assert.are.equal(1, #mock_metrics.histogram_observations)
            local observation = mock_metrics.histogram_observations[1]
            assert.are.equal("success", observation.type)
            assert.are.equal("cache_operation_duration_seconds", observation.name)
            assert.are.equal(10.0, observation.duration)
            assert.are.equal("get", observation.labels.operation)
            assert.are.equal("redis", observation.labels.cache_name)
        end)

        it("should record failure metrics when get operation fails", function()
            mock_inner.get = function(self, key) error("Redis connection failed") end

            assert.has_error(function()
                decorator:get("test_key")
            end)

            assert.are.equal(1, #mock_metrics.histogram_observations)
            local observation = mock_metrics.histogram_observations[1]
            assert.are.equal("failure", observation.type)
            assert.are.equal("cache_operation_duration_seconds", observation.name)
            assert.are.equal(10.0, observation.duration)
            assert.are.equal("get", observation.labels.operation)
            assert.are.equal("redis", observation.labels.cache_name)
        end)
    end)

    describe("set", function()
        it("should store value and return true when decorated storage succeeds", function()
            local test_value = "test_value"

            local result = decorator:set("test_key", test_value, 60, 300)

            assert.is_true(result)
            assert.are.equal(test_value, mock_inner.stored_data["test_key"])
        end)

        it("should record success metrics for successful set", function()
            decorator:set("test_key", "test_value", 60, 300)

            assert.are.equal(1, #mock_metrics.histogram_observations)
            local observation = mock_metrics.histogram_observations[1]
            assert.are.equal("success", observation.type)
            assert.are.equal("cache_operation_duration_seconds", observation.name)
            assert.are.equal(10.0, observation.duration)
            assert.are.equal("set", observation.labels.operation)
            assert.are.equal("redis", observation.labels.cache_name)
        end)

        it("should record failure metrics when set operation fails", function()
            mock_inner.set = function(self, key, value, tts, ttl) error("Redis write failed") end

            assert.has_error(function()
                decorator:set("test_key", "test_value")
            end)

            assert.are.equal(1, #mock_metrics.histogram_observations)
            local observation = mock_metrics.histogram_observations[1]
            assert.are.equal("failure", observation.type)
            assert.are.equal("cache_operation_duration_seconds", observation.name)
            assert.are.equal(10.0, observation.duration)
            assert.are.equal("set", observation.labels.operation)
            assert.are.equal("redis", observation.labels.cache_name)
        end)
    end)

    describe("del", function()
        it("should delete value and return true when decorated storage succeeds", function()
            mock_inner.stored_data["test_key"] = "some_data"

            local result = decorator:del("test_key")

            assert.is_true(result)
            assert.is_nil(mock_inner.stored_data["test_key"])
        end)

        it("should record success metrics for successful del", function()
            mock_inner.stored_data["test_key"] = "some_data"

            decorator:del("test_key")

            assert.are.equal(1, #mock_metrics.histogram_observations)
            local observation = mock_metrics.histogram_observations[1]
            assert.are.equal("success", observation.type)
            assert.are.equal("cache_operation_duration_seconds", observation.name)
            assert.are.equal(10.0, observation.duration)
            assert.are.equal("delete", observation.labels.operation)
            assert.are.equal("redis", observation.labels.cache_name)
        end)

        it("should record failure metrics when del operation fails", function()
            mock_inner.del = function(self, key) error("Redis delete failed") end

            assert.has_error(function()
                decorator:del("test_key")
            end)

            assert.are.equal(1, #mock_metrics.histogram_observations)
            local observation = mock_metrics.histogram_observations[1]
            assert.are.equal("failure", observation.type)
            assert.are.equal("cache_operation_duration_seconds", observation.name)
            assert.are.equal(10.0, observation.duration)
            assert.are.equal("delete", observation.labels.operation)
            assert.are.equal("redis", observation.labels.cache_name)
        end)
    end)

    describe("metrics timing", function()
        it("should measure actual operation duration", function()
            local slow_operation_duration = 50.0
            mock_inner.get = function(self, key)
                current_time = current_time + slow_operation_duration
                return "slow_result"
            end

            decorator:get("test_key")

            local observation = mock_metrics.histogram_observations[1]
            assert.are.equal(slow_operation_duration + 10.0, observation.duration)
        end)
    end)
end)
