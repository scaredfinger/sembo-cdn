local describe = require('busted').describe
local before_each = require('busted').before_each
local it = require('busted').it

local assert = require('luassert')
local spy = require('luassert.spy')

local Response = require('modules.http.response')
local Request = require('modules.http.request')

local SurrogateKeyMiddleware = require('modules.surrogate.middleware')

describe("SurrogateKeyMiddleware", function()
    local test_request = Request:new("GET", "/test/path", {}, "", {}, "localhost")
    local test_response = Response:new(200, "Test response", {})

    --- @type fun(request: Request): Response
    local function next(request)
        return test_response
    end

    --- @type fun(request: Request): string
    local function test_cache_key_strategy(request)
        return "cache:" .. request.host .. ":" .. request.path
    end

    local fake_cache_provider
    
    --- @type SurrogateKeyMiddleware
    local sut

    before_each(function()
        fake_cache_provider = {
            get = function(self, key)
                return nil
            end,
            set = function(self, key, value, tts, ttl)
                return true
            end,
            del = function(self, key)
                return true
            end,
            add_key_to_tag = function(self, key, tag)
                return true
            end,
            remove_key_from_tag = function(self, tag, key)
                return true
            end,
            del_by_tag = function(self, tag)
                return true
            end
        }
        
        sut = SurrogateKeyMiddleware:new(fake_cache_provider, test_cache_key_strategy)
        test_response.locals = {}
        test_response.headers = {}
    end)

    it("can be instantiated", function()
        assert.is_not_nil(sut)
        assert.is_true(getmetatable(sut) == SurrogateKeyMiddleware)
    end)

    it("stores cache provider on instantiation", function()
        assert.equal(fake_cache_provider, sut.provider)
    end)

    it("stores cache key strategy on instantiation", function()
        assert.equal(test_cache_key_strategy, sut.cache_key_strategy)
    end)

    describe("_assign_tags_to_cache_key", function()
        it("calls add_key_to_tag for each tag", function()
            local add_key_to_tag_spy = spy.on(fake_cache_provider, "add_key_to_tag")
            local cache_key = "cache:localhost:/test/path"
            local tags = {"hotel:luxury-resort", "pricing:2024"}

            sut:_assign_tags_to_cache_key(cache_key, tags)

            assert.spy(add_key_to_tag_spy).was_called(2)
            assert.spy(add_key_to_tag_spy).was_called_with(fake_cache_provider, cache_key, "hotel:luxury-resort")
            assert.spy(add_key_to_tag_spy).was_called_with(fake_cache_provider, cache_key, "pricing:2024")
        end)

        it("handles empty tags list", function()
            local add_key_to_tag_spy = spy.on(fake_cache_provider, "add_key_to_tag")
            local cache_key = "cache:localhost:/test/path"
            local tags = {}

            sut:_assign_tags_to_cache_key(cache_key, tags)

            assert.spy(add_key_to_tag_spy).was_not_called()
        end)
    end)

    describe("execute", function()
        it("calls next middleware", function()
            local next_spy = spy.new(next)

            sut:execute(test_request, next_spy)

            assert.spy(next_spy).was_called(1)
            assert.spy(next_spy).was_called_with(test_request)
        end)

        it("returns the response from next middleware", function()
            local response = sut:execute(test_request, next)

            assert.equal(test_response, response)
        end)

        it("does not modify the request", function()
            local original_path = test_request.path
            local original_method = test_request.method
            
            sut:execute(test_request, next)

            assert.equal(original_path, test_request.path)
            assert.equal(original_method, test_request.method)
        end)

        it("does not modify the response when no Surrogate-Key header", function()
            local original_status = test_response.status
            local original_body = test_response.body
            
            local response = sut:execute(test_request, next)

            assert.equal(original_status, response.status)
            assert.equal(original_body, response.body)
        end)

        it("does not call cache provider when no Surrogate-Key header", function()
            local add_key_to_tag_spy = spy.on(fake_cache_provider, "add_key_to_tag")
            
            sut:execute(test_request, next)

            assert.spy(add_key_to_tag_spy).was_not_called()
        end)

        it("does not call cache provider when Surrogate-Key header is empty", function()
            test_response.headers["Surrogate-Key"] = ""
            local add_key_to_tag_spy = spy.on(fake_cache_provider, "add_key_to_tag")
            
            sut:execute(test_request, next)

            assert.spy(add_key_to_tag_spy).was_not_called()
        end)

        it("does not call cache provider when Surrogate-Key header contains only whitespace", function()
            test_response.headers["Surrogate-Key"] = "   "
            local add_key_to_tag_spy = spy.on(fake_cache_provider, "add_key_to_tag")
            
            sut:execute(test_request, next)

            assert.spy(add_key_to_tag_spy).was_not_called()
        end)

        it("processes single tag in Surrogate-Key header", function()
            test_response.headers["Surrogate-Key"] = "hotel:luxury-resort"
            local add_key_to_tag_spy = spy.on(fake_cache_provider, "add_key_to_tag")
            
            sut:execute(test_request, next)

            assert.spy(add_key_to_tag_spy).was_called(1)
            assert.spy(add_key_to_tag_spy).was_called_with(fake_cache_provider, "cache:localhost:/test/path", "hotel:luxury-resort")
        end)

        it("processes multiple tags in Surrogate-Key header", function()
            test_response.headers["Surrogate-Key"] = "hotel:luxury-resort pricing:2024 availability:current"
            local add_key_to_tag_spy = spy.on(fake_cache_provider, "add_key_to_tag")
            
            sut:execute(test_request, next)

            assert.spy(add_key_to_tag_spy).was_called(3)
            assert.spy(add_key_to_tag_spy).was_called_with(fake_cache_provider, "cache:localhost:/test/path", "hotel:luxury-resort")
            assert.spy(add_key_to_tag_spy).was_called_with(fake_cache_provider, "cache:localhost:/test/path", "pricing:2024")
            assert.spy(add_key_to_tag_spy).was_called_with(fake_cache_provider, "cache:localhost:/test/path", "availability:current")
        end)

        it("uses cache key strategy to generate cache key", function()
            test_response.headers["Surrogate-Key"] = "hotel:luxury-resort"
            local cache_key_strategy_spy = spy.new(test_cache_key_strategy)
            local middleware = SurrogateKeyMiddleware:new(fake_cache_provider, cache_key_strategy_spy)
            
            middleware:execute(test_request, next)

            assert.spy(cache_key_strategy_spy).was_called(1)
            assert.spy(cache_key_strategy_spy).was_called_with(test_request)
        end)

        it("handles different request properties in cache key generation", function()
            local different_request = Request:new("POST", "/hotel/premium", {}, "", {}, "example.com")
            test_response.headers["Surrogate-Key"] = "hotel:premium"
            local add_key_to_tag_spy = spy.on(fake_cache_provider, "add_key_to_tag")
            
            sut:execute(different_request, next)

            assert.spy(add_key_to_tag_spy).was_called(1)
            assert.spy(add_key_to_tag_spy).was_called_with(fake_cache_provider, "cache:example.com:/hotel/premium", "hotel:premium")
        end)

        it("returns response unchanged after processing tags", function()
            test_response.headers["Surrogate-Key"] = "hotel:luxury-resort"
            local original_status = test_response.status
            local original_body = test_response.body
            local original_headers = test_response.headers
            
            local response = sut:execute(test_request, next)

            assert.equal(original_status, response.status)
            assert.equal(original_body, response.body)
            assert.equal(original_headers, response.headers)
            assert.equal(test_response, response)
        end)
    end)
end)
