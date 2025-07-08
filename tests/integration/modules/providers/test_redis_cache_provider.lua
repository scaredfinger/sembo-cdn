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
        
        local function open_connection()
            local client = redis:new()
            client:connect(REDIS_HOST, REDIS_PORT)
            return client
        end
        
        local function close_connection(connection)
            return true -- Connection pooling handled by resty.redis
        end
        
        cache_provider = RedisCacheProvider:new(open_connection, close_connection, nil)
    end)

    after_each(function()
        if redis_client then
            -- redis_client:close()
        end
    end)

    it("creates an instance", function()
        local function open_connection() return redis_client end
        local function close_connection(connection) return true end
        local provider = RedisCacheProvider:new(open_connection, close_connection, nil)
        assert.is_not_nil(provider)
        assert.is_function(provider.open_connection)
        assert.is_function(provider.close_connection)
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

    it("health check returns true when connected", function()
        assert.is_true(cache_provider:health())
    end)

    it("health check returns false when disconnected", function()
        local disconnected_client = redis:new()
        local function open_connection() return disconnected_client end
        local function close_connection(connection) return true end
        local provider = RedisCacheProvider:new(open_connection, close_connection, nil)
        assert.is_false(provider:health())
    end)
end)
    