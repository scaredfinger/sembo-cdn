local RedisCacheProvider = require "modules.providers.redis_cache_provider"

-- Mock Redis client
local MockRedisClient = {}
MockRedisClient.__index = MockRedisClient

function MockRedisClient:new()
    return setmetatable({
        connected = true
    }, MockRedisClient)
end

function MockRedisClient:ping()
    if self.connected then
        return "PONG"
    else
        error("Redis connection failed")
    end
end

function MockRedisClient:disconnect()
    self.connected = false
end

-- Test suite
describe("RedisCacheProvider", function()
    local redis_client
    local cache_provider
    
    before_each(function()
        redis_client = MockRedisClient:new()
        cache_provider = RedisCacheProvider:new(redis_client)
    end)
    
    it("should create an instance and check health", function()
        -- Test instance creation
        assert.is_not_nil(cache_provider)
        assert.are.equal("table", type(cache_provider))
        
        -- Test health check
        local is_healthy = cache_provider:health()
        assert.is_true(is_healthy)
    end)
end)
