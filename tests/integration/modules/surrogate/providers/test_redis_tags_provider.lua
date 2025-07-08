local describe = require('busted').describe
local before_each = require('busted').before_each
local after_each = require('busted').after_each
local it = require('busted').it

local assert = require('luassert')

local redis = require('modules.resty_compat_redis')

_G.ngx = {
  log = function(...) end,
  ERR = "ERR",
  say = function(...) end,
  exit = function(code) error("exit: " .. tostring(code)) end,
  timer = {
    at = function(...) return true end
  }
}

local RedisTagsProvider = require('modules.surrogate.providers.redis_tags_provider')

-- Connection constants
local REDIS_HOST = "host.docker.internal" -- Use host.docker.internal for Docker on Mac/Windows
local REDIS_PORT = 6379

describe("RedisTagsProvider Integration", function()
    local redis_client
    local tags_provider

    before_each(function()
        redis_client = redis:new()
        assert(redis_client:connect(REDIS_HOST, REDIS_PORT))
        
        local function open_connection()
            local client = redis:new()
            client:connect(REDIS_HOST, REDIS_PORT)
            return client
        end
        
        local function close_connection(connection)
            return true -- Connection pooling handled by resty.redis
        end
        
        tags_provider = RedisTagsProvider:new(open_connection, close_connection)
    end)

    after_each(function()
        if redis_client then
            -- redis_client:close()
        end
    end)

    it("creates an instance", function()
        local function open_connection()
            return redis:new()
        end
        
        local function close_connection(connection)
            return true
        end
        
        local provider = RedisTagsProvider:new(open_connection, close_connection)
        assert.is_not_nil(provider)
        assert.is_function(provider.open_connection)
        assert.is_function(provider.close_connection)
    end)

    it("adds key to tag", function()
        local key, tag = "test_key", "test_tag"
        assert.is_true(tags_provider:add_key_to_tag(key, tag))
        local members = redis_client:smembers(tag)
        assert.same(members, {key})
    end)

    it("removes key from tag", function()
        local key, tag = "test_key", "test_tag"
        tags_provider:add_key_to_tag(key, tag)
        assert.is_true(tags_provider:remove_key_from_tag(tag, key))
        local members = redis_client:smembers(tag)
        assert.same(members, {})
    end)

    it("deletes by tag", function()
        local tag, key1, key2 = "test_tag", "key1", "key2"
        -- Set up some cache keys (using raw redis client for test setup)
        redis_client:set(key1, "value1")
        redis_client:set(key2, "value2")
        tags_provider:add_key_to_tag(key1, tag)
        tags_provider:add_key_to_tag(key2, tag)
        assert.is_true(tags_provider:del_by_tag(tag))
        -- Check that the keys were deleted
        assert.is_nil(redis_client:get(key1))
        assert.is_nil(redis_client:get(key2))
        -- Check that the tag set was deleted
        local members = redis_client:smembers(tag)
        assert.same(members, {})
    end)

    it("deletes by empty tag", function()
        assert.is_true(tags_provider:del_by_tag("empty_tag"))
    end)

    it("handles complex tagging scenario", function()
        local user_tag, session_tag = "user:123", "session:abc"
        local key1, key2, key3 = "user:123:profile", "user:123:settings", "session:abc:data"
        
        -- Set up cache keys (using raw redis client for test setup)
        redis_client:set(key1, '{"name": "John"}')
        redis_client:set(key2, '{"theme": "dark"}')
        redis_client:set(key3, '{"token": "xyz"}')
        
        tags_provider:add_key_to_tag(key1, user_tag)
        tags_provider:add_key_to_tag(key2, user_tag)
        tags_provider:add_key_to_tag(key3, session_tag)
        
        assert.is_not_nil(redis_client:get(key1))
        assert.is_not_nil(redis_client:get(key2))
        assert.is_not_nil(redis_client:get(key3))
        
        tags_provider:del_by_tag(user_tag)
        
        assert.is_nil(redis_client:get(key1))
        assert.is_nil(redis_client:get(key2))
        assert.is_not_nil(redis_client:get(key3))
    end)
end)
