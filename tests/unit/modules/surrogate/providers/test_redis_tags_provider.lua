local describe = require('busted').describe
local before_each = require('busted').before_each
local it = require('busted').it
local assert = require('luassert')

local RedisTagsProvider = require "modules.surrogate.providers.redis_tags_provider"

-- Mock Redis client
local MockRedisClient = {}
MockRedisClient.__index = MockRedisClient

function MockRedisClient:new()
    return setmetatable({
        connected = true,
        sets = {}
    }, MockRedisClient)
end

function MockRedisClient:sadd(tag, key)
    if not self.sets[tag] then
        self.sets[tag] = {}
    end
    table.insert(self.sets[tag], key)
    return 1
end

function MockRedisClient:srem(tag, key)
    if not self.sets[tag] then
        return 0
    end
    for i, v in ipairs(self.sets[tag]) do
        if v == key then
            table.remove(self.sets[tag], i)
            return 1
        end
    end
    return 0
end

function MockRedisClient:smembers(tag)
    return self.sets[tag] or {}
end

function MockRedisClient:del(keys)
    if type(keys) == "table" then
        return #keys
    else
        self.sets[keys] = nil
        return 1
    end
end

-- Test suite
describe("RedisTagsProvider", function()
    local redis_client
    local tags_provider
    
    before_each(function()
        redis_client = MockRedisClient:new()
        
        local function open_connection()
            return redis_client
        end
        
        local function close_connection(connection)
            return true
        end
        
        tags_provider = RedisTagsProvider:new(open_connection, close_connection)
    end)
    
    it("should create an instance", function()
        -- Test instance creation
        assert.is_not_nil(tags_provider)
        assert.are.equal("table", type(tags_provider))
        assert.is_function(tags_provider.open_connection)
        assert.is_function(tags_provider.close_connection)
    end)
    
    it("should add key to tag", function()
        local key, tag = "test_key", "test_tag"
        local result = tags_provider:add_key_to_tag(key, tag)
        assert.is_true(result)
        assert.same(redis_client.sets[tag], {key})
    end)
    
    it("should remove key from tag", function()
        local key, tag = "test_key", "test_tag"
        tags_provider:add_key_to_tag(key, tag)
        local result = tags_provider:remove_key_from_tag(tag, key)
        assert.is_true(result)
        assert.same(redis_client.sets[tag], {})
    end)
    
    it("should get keys for tag", function()
        local tag = "test_tag"
        local key1, key2 = "key1", "key2"
        tags_provider:add_key_to_tag(key1, tag)
        tags_provider:add_key_to_tag(key2, tag)
        
        local keys = tags_provider:get_keys_for_tag(tag)
        assert.are.same({key1, key2}, keys)
    end)
    
    it("should return empty table for non-existent tag", function()
        local keys = tags_provider:get_keys_for_tag("non_existent_tag")
        assert.are.same({}, keys)
    end)
    
    it("should delete by tag", function()
        local tag, key1, key2 = "test_tag", "key1", "key2"
        tags_provider:add_key_to_tag(key1, tag)
        tags_provider:add_key_to_tag(key2, tag)
        local result = tags_provider:del_by_tag(tag)
        assert.is_true(result)
        assert.is_nil(redis_client.sets[tag])
    end)
end)
