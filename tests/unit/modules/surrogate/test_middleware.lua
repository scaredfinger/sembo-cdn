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
        
        sut = SurrogateKeyMiddleware:new(fake_cache_provider)
        test_response.locals = {}
    end)

    it("can be instantiated", function()
        assert.is_not_nil(sut)
        assert.is_true(getmetatable(sut) == SurrogateKeyMiddleware)
    end)

    it("stores cache provider on instantiation", function()
        assert.equal(fake_cache_provider, sut.provider)
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

        it("does not modify the response", function()
            local original_status = test_response.status
            local original_body = test_response.body
            
            local response = sut:execute(test_request, next)

            assert.equal(original_status, response.status)
            assert.equal(original_body, response.body)
        end)
    end)
end)
