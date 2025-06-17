
local describe = require('busted').describe
local before_each = require('busted').before_each
local it = require('busted').it
local assert = require('luassert')

local spy = require('luassert.spy')
local stub = require('luassert.stub')

local CacheMiddleware = require('modules.cache_middleware')
local Response = require('modules.http.response')
local Request = require('modules.http.request')

describe("CachMiddleware", function()
    local fake_cache

    --- @type fun(request: Request): string
    local create_key = function (request)
        return request.method .. ":" .. request.host .. ":" .. request.path
    end

    --- @type CacheMiddleware
    local sut

    before_each(function()
        fake_cache = {
            values = {},
            get = function(self, key)
                return self.dic[key] or nil
            end,
            set = function(self, key, value, ttl)
                self.values[key] = value
                return true
            end,
            del = function(self, key)
                if self.values[key] then
                    self.values[key] = nil
                    return true
                end
                return false
            end,
        }

        sut = CacheMiddleware:new(fake_cache, create_key)
        
    end)

    it("can be instantiated", function()
        assert.is_not_nil(sut)
        assert.is_true(getmetatable(sut) == CacheMiddleware)
    end)

    describe("when method is not GET", function()

        local expected_request = Request:new("POST", "/test", {}, "Request body")

        local next_body = "Response body"

        local next_response = Response:new(200, next_body, {})

        --- @type fun(request: Request): Response | nil
        local next = function(request)
            if (request ~= expected_request) then
                return nil
            end
            return next_response
        end
        
        it("just allows the request to proceed", function()
            local response = sut:execute(expected_request, next)

            assert.equal(next_response, response)
        end)
    end)

    describe("when method is GET", function()

        local expected_request = Request:new("GET", "/test", {}, "Request body")

        local next_body = "Response body"

        local next_response = Response:new(200, next_body, {})

        --- @type fun(request: Request): Response | nil
        local next = function(request)
            if (request ~= expected_request) then
                return nil
            end
            return next_response
        end

        describe("when item is not cached", function()

            before_each(function()
                fake_cache:del(create_key(expected_request))
            end)

            it("calls next", function()
                local next_spy = spy.new(next)

                local response = sut:execute(expected_request, next_spy)

                assert.equal(next_response, response)
            end)

            describe("when next returns a cacheable response", function()

                local cacheable_response = Response:new(200, "Cacheable response", { ["Cache-Control"] = "public, max-age=3600" })

            
                it("caches the response", function()
                    local next_spy = spy.new(next)

                    sut:execute(expected_request, next_spy)

                    local cache_key = create_key(expected_request)
                    assert.is_not_nil(fake_cache.values[cache_key])
                    assert.equal(next_response.body, fake_cache.values[cache_key].body)
                end)

            end)

            it("caches the response", function()
                local next_spy = spy.new(next)

                sut:execute(expected_request, next_spy)

                local cache_key = create_key(expected_request)
                assert.is_not_nil(fake_cache.values[cache_key])
                assert.equal(next_response.body, fake_cache.values[cache_key].body)
            end)

        end)

    end)

  end)