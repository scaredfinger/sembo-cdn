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

local RedisCacheProvider = require('modules.cache.providers.redis_cache_provider')

-- Connection constants
local REDIS_HOST = "host.docker.internal" -- Use host.docker.internal for Docker on Mac/Windows
local REDIS_PORT = 6379

describe("RedisCacheProvider Integration", function()
    local redis_client
    local cache_provider

    before_each(function()
        redis_client = redis:new()
        assert(redis_client:connect(REDIS_HOST, REDIS_PORT))
        cache_provider = RedisCacheProvider:new(redis_client)
    end)

    after_each(function()
        if redis_client then
            -- redis_client:close()
        end
    end)

    it("creates an instance", function()
        local provider = RedisCacheProvider:new(redis_client)
        assert.is_not_nil(provider)
        assert.equals(provider.redis, redis_client)
    end)

    it("sets and gets a string", function()
        local key, value = "test_string", "hello world"
        assert.is_true(cache_provider:set(key, value))
        assert.equals(cache_provider:get(key), value)
    end)

    it("sets and gets a number", function()
        local key, value = "test_number", 42
        assert.is_true(cache_provider:set(key, value))
        assert.equals(cache_provider:get(key), value)
    end)

    it("sets and gets a table", function()
        local key, value = "test_table", {name = "John", age = 30, active = true}
        assert.is_true(cache_provider:set(key, value))
        local retrieved = cache_provider:get(key)
        assert.same(retrieved, value)
    end)

    it("sets with ttl", function()
        local key, value, ttl = "test_ttl", "expires soon", 2
        assert.is_true(cache_provider:set(key, value, nil, ttl))
        assert.equals(cache_provider:get(key), value)
        local ttl_result = redis_client:ttl(key)
        assert.is_true(ttl_result > 0 and ttl_result <= ttl)
    end)

    it("returns nil for nonexistent key", function()
        assert.is_nil(cache_provider:get("nonexistent_key"))
    end)

    it("deletes an existing key", function()
        local key, value = "test_delete", "to be deleted"
        cache_provider:set(key, value)
        assert.is_not_nil(cache_provider:get(key))
        assert.is_true(cache_provider:del(key))
        assert.is_nil(cache_provider:get(key))
    end)

    it("deletes a nonexistent key", function()
        assert.equals(cache_provider:del("nonexistent_key"), 0)
    end)

    it("adds key to tag", function()
        local key, tag = "test_key", "test_tag"
        assert.is_true(cache_provider:add_key_to_tag(key, tag))
        local members = redis_client:smembers(tag)
        assert.same(members, {key})
    end)

    it("removes key from tag", function()
        local key, tag = "test_key", "test_tag"
        cache_provider:add_key_to_tag(key, tag)
        assert.is_true(cache_provider:remove_key_from_tag(tag, key))
        local members = redis_client:smembers(tag)
        assert.same(members, {})
    end)

    it("deletes by tag", function()
        local tag, key1, key2 = "test_tag", "key1", "key2"
        cache_provider:set(key1, "value1")
        cache_provider:set(key2, "value2")
        cache_provider:add_key_to_tag(key1, tag)
        cache_provider:add_key_to_tag(key2, tag)
        assert.is_true(cache_provider:del_by_tag(tag))
        assert.is_nil(cache_provider:get(key1))
        assert.is_nil(cache_provider:get(key2))
        local members = redis_client:smembers(tag)
        assert.same(members, {})
    end)

    it("deletes by empty tag", function()
        assert.is_true(cache_provider:del_by_tag("empty_tag"))
    end)

    it("health check returns true when connected", function()
        assert.is_true(cache_provider:health())
    end)

    it("health check returns false when disconnected", function()
        local disconnected_client = redis:new()
        local provider = RedisCacheProvider:new(disconnected_client)
        assert.is_false(provider:health())
    end)

    it("disconnects successfully", function()
        local test_client = redis:new()
        test_client:set_timeout(REDIS_TIMEOUT)
        test_client:connect(REDIS_HOST, REDIS_PORT)
        local provider = RedisCacheProvider:new(test_client)
        assert.is_true(provider:disconnect())
    end)

    it("handles complex tagging scenario", function()
        local user_tag, session_tag = "user:123", "session:abc"
        local key1, key2, key3 = "user:123:profile", "user:123:settings", "session:abc:data"
        cache_provider:set(key1, {name = "John"})
        cache_provider:set(key2, {theme = "dark"})
        cache_provider:set(key3, {token = "xyz"})
        cache_provider:add_key_to_tag(key1, user_tag)
        cache_provider:add_key_to_tag(key2, user_tag)
        cache_provider:add_key_to_tag(key3, session_tag)
        assert.is_not_nil(cache_provider:get(key1))
        assert.is_not_nil(cache_provider:get(key2))
        assert.is_not_nil(cache_provider:get(key3))
        cache_provider:del_by_tag(user_tag)
        assert.is_nil(cache_provider:get(key1))
        assert.is_nil(cache_provider:get(key2))
        assert.is_not_nil(cache_provider:get(key3))
    end)
end)
    