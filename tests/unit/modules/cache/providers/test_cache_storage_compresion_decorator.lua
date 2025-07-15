local describe = require('busted').describe
local before_each = require('busted').before_each
local it = require('busted').it
local assert = require('luassert')

local CacheProviderCompressionDecorator = require("modules.cache.providers.cache_storage_compression_decorator")

describe("CacheProviderGzipDecorator", function()
    local mock_inner
    local mock_encode
    local mock_decode
    local decorator

    before_each(function()
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

        mock_encode = function(data)
            return "compressed_" .. data
        end

        mock_decode = function(data)
            if data:sub(1, 11) == "compressed_" then
                return data:sub(12)
            end
            return nil
        end

        decorator = CacheProviderCompressionDecorator:new(
            mock_inner,
            mock_encode,
            mock_decode
        )
    end)

    describe("new", function()
        it("should create decorator with provided cache provider", function()
            assert.are.equal(mock_inner, decorator.inner)
        end)

        it("should use provided compression functions", function()
            assert.are.equal(mock_encode, decorator.encode)
            assert.are.equal(mock_decode, decorator.decode)
        end)
    end)

    describe("get", function()
        it("should return nil when decorated provider returns nil", function()
            mock_inner.get = function(self, key) return nil end

            local result = decorator:get("test_key")

            assert.is_nil(result)
        end)

        it("should decompress and return value when decorated provider returns compressed data", function()
            local test_value = "test_value"
            mock_inner.stored_data["test_key"] = "compressed_test_value"

            local result = decorator:get("test_key")

            assert.are.equal(test_value, result)
        end)

        it("should return nil when base64 decoding fails", function()
            mock_inner.stored_data["test_key"] = "invalid_base64_data"

            local result = decorator:get("test_key")

            assert.is_nil(result)
        end)
    end)

    describe("set", function()
        it("should compress value and call decorated provider set", function()
            local test_value = "test_value"

            local result = decorator:set("test_key", test_value, 60, 300)

            assert.is_true(result)
            assert.are.equal("compressed_test_value", mock_inner.stored_data["test_key"])
        end)

        it("should return false when compression fails", function()
            local failing_deflate = function(data) return nil end
            local failing_decorator = CacheProviderCompressionDecorator:new(
                mock_inner,
                failing_deflate,
                mock_decode
            )

            local result = failing_decorator:set("test_key", "test_value")

            assert.is_false(result)
        end)
    end)

    describe("del", function()
        it("should call decorated provider del method", function()
            mock_inner.stored_data["test_key"] = "some_data"

            local result = decorator:del("test_key")

            assert.is_true(result)
            assert.is_nil(mock_inner.stored_data["test_key"])
        end)
    end)
end)
