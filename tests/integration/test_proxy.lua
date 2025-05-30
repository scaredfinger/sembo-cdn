-- Integration tests for proxy functionality
-- These tests require a running environment with Redis and backend

describe("proxy integration", function()
    local http = require "resty.http"
    local cache = require "modules.cache"
    
    -- Skip tests if not in integration environment
    local function skip_if_no_redis()
        local healthy, _ = cache.health_check()
        if not healthy then
            pending("Redis not available")
        end
    end
    
    describe("health endpoint", function()
        it("should return health status", function()
            skip_if_no_redis()
            
            local httpc = http.new()
            local res, err = httpc:request_uri("http://localhost:8080/health")
            
            assert.is_nil(err)
            assert.is_not_nil(res)
            assert.is_true(res.status == 200 or res.status == 503)
            assert.equals("application/json", res.headers["Content-Type"])
        end)
    end)
    
    describe("metrics endpoint", function()
        it("should return Prometheus metrics", function()
            local httpc = http.new()
            local res, err = httpc:request_uri("http://localhost:9090/metrics")
            
            assert.is_nil(err)
            assert.is_not_nil(res)
            assert.equals(200, res.status)
            assert.is_true(string.find(res.headers["Content-Type"], "text/plain") ~= nil)
            assert.is_true(string.find(res.body, "# HELP") ~= nil)
        end)
    end)
    
    describe("proxy functionality", function()
        it("should proxy requests to backend", function()
            skip_if_no_redis()
            
            local httpc = http.new()
            local res, err = httpc:request_uri("http://localhost:8080/test")
            
            assert.is_nil(err)
            assert.is_not_nil(res)
            assert.is_not_nil(res.headers["X-Cache-Status"])
            assert.is_not_nil(res.headers["X-Proxy-Server"])
            assert.equals("sembo-cdn", res.headers["X-Proxy-Server"])
        end)
        
        it("should cache GET responses", function()
            skip_if_no_redis()
            
            local httpc = http.new()
            
            -- First request (should be MISS)
            local res1, err1 = httpc:request_uri("http://localhost:8080/cache-test")
            assert.is_nil(err1)
            assert.equals("MISS", res1.headers["X-Cache-Status"])
            
            -- Second request (should be HIT)
            local res2, err2 = httpc:request_uri("http://localhost:8080/cache-test")
            assert.is_nil(err2)
            assert.equals("HIT", res2.headers["X-Cache-Status"])
        end)
    end)
end)
