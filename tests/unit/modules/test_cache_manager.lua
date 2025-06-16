local CacheManager = require('src.modules.cache_manager')

local describe = require('busted').describe
local before_each = require('busted').before_each
local it = require('busted').it
local assert = require('luassert')

local spy = require('luassert.spy')
local stub = require('luassert.stub')

describe("CacheManager", function()
    local mock_provider
    local cache_manager

    before_each(function()
        -- Create a mock cache provider
        mock_provider = {
            get = function(self, key) return nil end,
            set = spy.new(function(self, key, value, ttl) return true end),
            del = spy.new(function(self, key) return true end),
            exists = spy.new(function(self, key) return false end),
            clear = spy.new(function(self) return true end),
            disconnect = spy.new(function(self) return true end)
        }
        
        cache_manager = CacheManager:new(mock_provider)
    end)

    describe("new", function()
        it("should create a new CacheManager instance", function()
            local manager = CacheManager:new(mock_provider)
            assert.is_not_nil(manager)
            assert.equals(mock_provider, manager.provider)
        end)

        it("should set the correct metatable", function()
            local manager = CacheManager:new(mock_provider)
            assert.equals(CacheManager, getmetatable(manager))
        end)
    end)

    describe("get", function()
        it("should call provider's get method", function()
            local get_spy = spy.on(mock_provider, "get")
            
            cache_manager:get("test_key")
            
            assert.spy(get_spy).was_called_with(mock_provider, "test_key")
        end)

        it("should return result from provider", function()
            stub(mock_provider, "get", function(self, key) if (key == "test_key") then return "test_value" end end)

            local result = cache_manager:get("test_key")
            
            assert.equals(result, "test_value")
        end)

        it("should return nil if key does not exist", function()
            stub(mock_provider, "get", function(self, key) if (key == "test_key") then return "test_value" end end)

            local result = cache_manager:get("non_existent_key")
            
            assert.is_nil(result)
        end)
    end)

    describe("set", function()
        it("should call provider's set method without TTL", function()
            local spy_set = spy.on(mock_provider, "set")
            
            local result = cache_manager:set("test_key", "test_value")
            
            assert.spy(spy_set).was_called_with(mock_provider, "test_key", "test_value", nil)
            assert.is_true(result)
        end)

        it("should call provider's set method with TTL", function()
            local spy_set = spy.on(mock_provider, "set")
            
            local result = cache_manager:set("test_key", "test_value", 300)
            
            assert.spy(spy_set).was_called_with(mock_provider, "test_key", "test_value", 300)
            assert.is_true(result)
        end)

        it("should handle set failure", function()
            mock_provider.set = function(self, key, value, ttl) return false end
            
            local result = cache_manager:set("test_key", "test_value")
            
            assert.is_false(result)
        end)
    end)

end)
