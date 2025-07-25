local describe = require('busted').describe
local before_each = require('busted').before_each
local it = require('busted').it
local assert = require('luassert')

local TagsProviderMetricsDecorator = require("modules.surrogate.providers.tags_provider_metrics_decorator")

describe("TagsProviderMetricsDecorator", function()
    local mock_inner
    local mock_metrics
    local mock_now
    local decorator
    local current_time

    before_each(function()
        current_time = 1000.0

        mock_inner = {
            tag_data = {},
            add_key_to_tag = function(self, key, tag)
                if not self.tag_data[tag] then
                    self.tag_data[tag] = {}
                end
                table.insert(self.tag_data[tag], key)
                return true
            end,
            remove_key_from_tag = function(self, tag, key)
                if self.tag_data[tag] then
                    for i, stored_key in ipairs(self.tag_data[tag]) do
                        if stored_key == key then
                            table.remove(self.tag_data[tag], i)
                            return true
                        end
                    end
                end
                return false
            end,
            get_keys_for_tag = function(self, tag)
                return self.tag_data[tag]
            end,
            del_by_tag = function(self, tag)
                self.tag_data[tag] = nil
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

        decorator = TagsProviderMetricsDecorator:new(
            mock_inner,
            mock_metrics,
            "tags_operation_duration_seconds",
            "redis"
        )
    end)

    describe("new", function()
        it("should create decorator with provided tags provider", function()
            assert.are.equal(mock_inner, decorator.inner)
        end)

        it("should use provided metrics instance", function()
            assert.are.equal(mock_metrics, decorator.metrics)
        end)

        it("should use provided metrics name", function()
            assert.are.equal("tags_operation_duration_seconds", decorator.metrics_name)
        end)

        it("should use provided provider name", function()
            assert.are.equal("redis", decorator.provider_name)
        end)
    end)

    describe("add_key_to_tag", function()
        it("should add key to tag and return true when decorated provider succeeds", function()
            local result = decorator:add_key_to_tag("test_key", "test_tag")

            assert.is_true(result)
            assert.are.equal(1, #mock_inner.tag_data["test_tag"])
            assert.are.equal("test_key", mock_inner.tag_data["test_tag"][1])
        end)

        it("should record success metrics for successful add_key_to_tag", function()
            decorator:add_key_to_tag("test_key", "test_tag")

            assert.are.equal(1, #mock_metrics.histogram_observations)
            local observation = mock_metrics.histogram_observations[1]
            assert.are.equal("success", observation.type)
            assert.are.equal("tags_operation_duration_seconds", observation.name)
            assert.are.equal(10.0, observation.duration)
            assert.are.equal("add_key_to_tag", observation.labels.operation)
            assert.are.equal("redis", observation.labels.provider)
        end)

        it("should record failure metrics when add_key_to_tag operation fails", function()
            mock_inner.add_key_to_tag = function(self, key, tag) error("Redis connection failed") end

            assert.has_error(function()
                decorator:add_key_to_tag("test_key", "test_tag")
            end)

            assert.are.equal(1, #mock_metrics.histogram_observations)
            local observation = mock_metrics.histogram_observations[1]
            assert.are.equal("failure", observation.type)
            assert.are.equal("tags_operation_duration_seconds", observation.name)
            assert.are.equal(10.0, observation.duration)
            assert.are.equal("add_key_to_tag", observation.labels.operation)
            assert.are.equal("redis", observation.labels.provider)
        end)
    end)

    describe("remove_key_from_tag", function()
        it("should remove key from tag and return true when decorated provider succeeds", function()
            -- Setup: add a key first
            mock_inner.tag_data["test_tag"] = {"test_key", "other_key"}

            local result = decorator:remove_key_from_tag("test_tag", "test_key")

            assert.is_true(result)
            assert.are.equal(1, #mock_inner.tag_data["test_tag"])
            assert.are.equal("other_key", mock_inner.tag_data["test_tag"][1])
        end)

        it("should return false when key is not found in tag", function()
            mock_inner.tag_data["test_tag"] = {"other_key"}

            local result = decorator:remove_key_from_tag("test_tag", "nonexistent_key")

            assert.is_false(result)
        end)

        it("should record success metrics for successful remove_key_from_tag", function()
            mock_inner.tag_data["test_tag"] = {"test_key"}

            decorator:remove_key_from_tag("test_tag", "test_key")

            assert.are.equal(1, #mock_metrics.histogram_observations)
            local observation = mock_metrics.histogram_observations[1]
            assert.are.equal("success", observation.type)
            assert.are.equal("tags_operation_duration_seconds", observation.name)
            assert.are.equal(10.0, observation.duration)
            assert.are.equal("remove_key_from_tag", observation.labels.operation)
            assert.are.equal("redis", observation.labels.provider)
        end)

        it("should record failure metrics when remove_key_from_tag operation fails", function()
            mock_inner.remove_key_from_tag = function(self, tag, key) error("Redis remove failed") end

            assert.has_error(function()
                decorator:remove_key_from_tag("test_tag", "test_key")
            end)

            assert.are.equal(1, #mock_metrics.histogram_observations)
            local observation = mock_metrics.histogram_observations[1]
            assert.are.equal("failure", observation.type)
            assert.are.equal("tags_operation_duration_seconds", observation.name)
            assert.are.equal(10.0, observation.duration)
            assert.are.equal("remove_key_from_tag", observation.labels.operation)
            assert.are.equal("redis", observation.labels.provider)
        end)
    end)

    describe("get_keys_for_tag", function()
        it("should return nil when decorated provider returns nil", function()
            mock_inner.get_keys_for_tag = function(self, tag) return nil end

            local result = decorator:get_keys_for_tag("test_tag")

            assert.is_nil(result)
        end)

        it("should return keys when decorated provider returns data", function()
            local test_keys = {"key1", "key2", "key3"}
            mock_inner.tag_data["test_tag"] = test_keys

            local result = decorator:get_keys_for_tag("test_tag")

            assert.are.same(test_keys, result)
        end)

        it("should record success metrics for successful get_keys_for_tag", function()
            mock_inner.tag_data["test_tag"] = {"key1", "key2"}

            decorator:get_keys_for_tag("test_tag")

            assert.are.equal(1, #mock_metrics.histogram_observations)
            local observation = mock_metrics.histogram_observations[1]
            assert.are.equal("success", observation.type)
            assert.are.equal("tags_operation_duration_seconds", observation.name)
            assert.are.equal(10.0, observation.duration)
            assert.are.equal("get_keys_for_tag", observation.labels.operation)
            assert.are.equal("redis", observation.labels.provider)
        end)

        it("should record failure metrics when get_keys_for_tag operation fails", function()
            mock_inner.get_keys_for_tag = function(self, tag) error("Redis read failed") end

            assert.has_error(function()
                decorator:get_keys_for_tag("test_tag")
            end)

            assert.are.equal(1, #mock_metrics.histogram_observations)
            local observation = mock_metrics.histogram_observations[1]
            assert.are.equal("failure", observation.type)
            assert.are.equal("tags_operation_duration_seconds", observation.name)
            assert.are.equal(10.0, observation.duration)
            assert.are.equal("get_keys_for_tag", observation.labels.operation)
            assert.are.equal("redis", observation.labels.provider)
        end)
    end)

    describe("del_by_tag", function()
        it("should delete tag and return true when decorated provider succeeds", function()
            mock_inner.tag_data["test_tag"] = {"key1", "key2"}

            local result = decorator:del_by_tag("test_tag")

            assert.is_true(result)
            assert.is_nil(mock_inner.tag_data["test_tag"])
        end)

        it("should record success metrics for successful del_by_tag", function()
            mock_inner.tag_data["test_tag"] = {"key1", "key2"}

            decorator:del_by_tag("test_tag")

            assert.are.equal(1, #mock_metrics.histogram_observations)
            local observation = mock_metrics.histogram_observations[1]
            assert.are.equal("success", observation.type)
            assert.are.equal("tags_operation_duration_seconds", observation.name)
            assert.are.equal(10.0, observation.duration)
            assert.are.equal("del_by_tag", observation.labels.operation)
            assert.are.equal("redis", observation.labels.provider)
        end)

        it("should record failure metrics when del_by_tag operation fails", function()
            mock_inner.del_by_tag = function(self, tag) error("Redis delete failed") end

            assert.has_error(function()
                decorator:del_by_tag("test_tag")
            end)

            assert.are.equal(1, #mock_metrics.histogram_observations)
            local observation = mock_metrics.histogram_observations[1]
            assert.are.equal("failure", observation.type)
            assert.are.equal("tags_operation_duration_seconds", observation.name)
            assert.are.equal(10.0, observation.duration)
            assert.are.equal("del_by_tag", observation.labels.operation)
            assert.are.equal("redis", observation.labels.provider)
        end)
    end)

    describe("metrics timing", function()
        it("should measure actual operation duration", function()
            local slow_operation_duration = 50.0
            mock_inner.get_keys_for_tag = function(self, tag)
                current_time = current_time + slow_operation_duration
                return {"slow_result"}
            end

            decorator:get_keys_for_tag("test_tag")

            local observation = mock_metrics.histogram_observations[1]
            assert.are.equal(slow_operation_duration + 10.0, observation.duration)
        end)
    end)
end)
