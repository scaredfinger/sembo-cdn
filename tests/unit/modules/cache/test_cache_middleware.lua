local describe = require('busted').describe
local before_each = require('busted').before_each
local it = require('busted').it

local assert = require('luassert')
local spy = require('luassert.spy')
local stub = require('luassert.stub')

local Response = require('modules.http.response')
local Request = require('modules.http.request')
local parse_cache_control = require('modules.cache.cache_control_parser')

local CacheMiddleware = require('modules.cache.cache_middleware')

-- Time constants
local ONE_HOUR = 3600
local ONE_DAY = 86400

describe("CachMiddleware", function()
    local cacheable_request = Request:new("GET", "/cacheable_request_test", {}, "", {}, "localhost")
    local cacheable_response = Response:new(200, "Cacheable response",
        { ["Cache-Control"] = "public, max-age=" .. ONE_HOUR .. ", stale-while-revalidate=" .. ONE_DAY })

    local cacheable_request_stale = Request:new("GET", "/cacheable_request_test", {}, "", {},
        "localhost", os.time() + 4000)
    local cacheable_request_expired = Request:new("GET", "/cacheable_request_test", {}, "",
        {}, "localhost", os.time() + 100000)

    local non_cacheable_request = Request:new("GET", "/non_cacheable_test", {}, "", {}, "localhost")
    local non_cacheable_response = Response:new(200, "Non-cacheable response", { ["Cache-Control"] = "no-cache" })

    local unknonw_request = Request:new("GET", "/unknown", {}, "", {}, "localhost")
    local unknonw_request_response = Response:new(200, "Not Found", {})

    function next(request)
        if request == cacheable_request then
            return cacheable_response
        elseif request == non_cacheable_request then
            return non_cacheable_response
        elseif request == cacheable_request_stale then
            return cacheable_response
        elseif request == cacheable_request_expired then
            return cacheable_response
        end

        return unknonw_request_response
    end

    --- @type fun()
    local deferred

    --- @type fun(callback: fun())
    local defer = function(callback)
        deferred = callback
    end

    local fake_cache

    --- @type fun(request: Request): string
    local create_key = function(request)
        return request.method .. ":" .. request.host .. ":" .. request.path
    end

    --- @type CacheMiddleware
    local sut

    before_each(function()
        fake_cache = {
            values = {},
            get = function(self, key)
                return self.values[key] or nil
            end,
            set = function(self, key, value, tts, ttl)
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

        sut = CacheMiddleware:new(fake_cache, create_key, parse_cache_control, defer)
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
        describe("when item is not cached", function()
            before_each(function()
                fake_cache:del(create_key(cacheable_request))
            end)

            it("calls next", function()
                local next_spy = spy.new(next)

                local response = sut:execute(cacheable_request, next_spy)

                assert.equal(cacheable_response, response)
            end)

            it("returns X-Cache: MISS header", function()
                local next_spy = spy.new(next)

                sut:execute(cacheable_request, next_spy)

                local cache_key = create_key(cacheable_request)
                assert.is_not_nil(fake_cache.values[cache_key])
                assert.equal("MISS", fake_cache.values[cache_key].headers["X-Cache"])
            end)

            it("returns X-Cache-Age: 0 header", function()
                local next_spy = spy.new(next)

                sut:execute(cacheable_request, next_spy)

                local cache_key = create_key(cacheable_request)
                assert.is_not_nil(fake_cache.values[cache_key])
                assert.equal("0", fake_cache.values[cache_key].headers["X-Cache-Age"])
            end)

            it("returns X-Cache-TTL: ONE_DAY header", function()
                local next_spy = spy.new(next)

                sut:execute(cacheable_request, next_spy)

                local cache_key = create_key(cacheable_request)
                assert.is_not_nil(fake_cache.values[cache_key])
                assert.equal(tostring(ONE_DAY), fake_cache.values[cache_key].headers["X-Cache-TTL"])
            end)

            it("returns X-Cache-TTS: ONE_HOUR header", function()
                local next_spy = spy.new(next)

                sut:execute(cacheable_request, next_spy)

                local cache_key = create_key(cacheable_request)
                assert.is_not_nil(fake_cache.values[cache_key])
                assert.equal(tostring(ONE_HOUR), fake_cache.values[cache_key].headers["X-Cache-TTS"])
            end)
        end)

        describe("when next returns a cacheable response", function()
            it("caches the response", function()
                sut:execute(cacheable_request, next)

                local cache_key = create_key(cacheable_request)
                assert.is_not_nil(fake_cache.values[cache_key])
                assert.equal(cacheable_response.body, fake_cache.values[cache_key].body)
            end)

            it("does not call next again for the same request", function()
                local next_spy = spy.new(next)

                sut:execute(cacheable_request, next_spy)
                sut:execute(cacheable_request, next_spy)

                assert.spy(next_spy).was_called(1)
            end)

            describe("when cached", function() 

                before_each(function()
                    sut:execute(cacheable_request, next)
                end)

                it("returns cached value", function()
                    local response = sut:execute(cacheable_request, next)

                    local cache_key = create_key(cacheable_request)
                    local cache_value = fake_cache.values[cache_key]
                    assert.equal(cache_value, response)
                end)

                it("does not call next again", function()
                    local next_spy = spy.new(next)

                    sut:execute(cacheable_request, next_spy)

                    assert.spy(next_spy).was_not_called()
                end)

                it("returns X-Cache: HIT header", function()
                    local next_spy = spy.new(next)

                    sut:execute(cacheable_request, next_spy)

                    local cache_key = create_key(cacheable_request)
                    assert.is_not_nil(fake_cache.values[cache_key])
                    assert.equal("HIT", fake_cache.values[cache_key].headers["X-Cache"])
                end)

                it("returns X-Cache-Age: 0 header", function()
                    local next_spy = spy.new(next)

                    sut:execute(cacheable_request, next_spy)

                    local cache_key = create_key(cacheable_request)
                    assert.is_not_nil(fake_cache.values[cache_key])
                    assert.equal("0", fake_cache.values[cache_key].headers["X-Cache-Age"])
                end)

                it("returns X-Cache-TTL: ONE_DAY header", function()
                    local next_spy = spy.new(next)

                    sut:execute(cacheable_request, next_spy)

                    local cache_key = create_key(cacheable_request)
                    assert.is_not_nil(fake_cache.values[cache_key])
                    assert.equal(tostring(ONE_DAY), fake_cache.values[cache_key].headers["X-Cache-TTL"])
                end)

                it("returns X-Cache-TTS: ONE_HOUR header", function()
                    local next_spy = spy.new(next)

                    sut:execute(cacheable_request, next_spy)

                    local cache_key = create_key(cacheable_request)
                    assert.is_not_nil(fake_cache.values[cache_key])
                    assert.equal(tostring(ONE_HOUR), fake_cache.values[cache_key].headers["X-Cache-TTS"])
                end)

            end)

            describe("when stale", function()
                before_each(function()
                    sut:execute(cacheable_request, next)
                end)

                it("returns cached value", function()
                    local response = sut:execute(cacheable_request_stale, next)

                    local cache_key = create_key(cacheable_request)
                    local cache_value = fake_cache.values[cache_key]
                    assert.equal(cache_value, response)
                end)

                it("does not call next again", function()
                    local next_spy = spy.new(next)

                    sut:execute(cacheable_request_stale, next_spy)

                    assert.spy(next_spy).was_not_called()
                end)

                it("does not override cached value", function()
                    sut:execute(cacheable_request_stale, next)

                    local cache_key = create_key(cacheable_request)
                    local cache_value = fake_cache.values[cache_key]
                    assert.equal(cache_value.stale_at, cacheable_request.timestamp + ONE_HOUR)
                    assert.equal(cache_value.expires_at, cacheable_request.timestamp + ONE_DAY)
                end)

                it("defers the cache update", function()
                    local next_spy = spy.new(next)
                    sut:execute(cacheable_request_stale, next_spy)

                    deferred()

                    local cache_key = create_key(cacheable_request)
                    local cache_value = fake_cache.values[cache_key]
                    assert.equal(cache_value.stale_at, cacheable_request_stale.timestamp + ONE_HOUR)
                    assert.equal(cache_value.expires_at, cacheable_request_stale.timestamp + ONE_DAY)
                    assert.spy(next_spy).was_called(1)
                end)

                it("returns X-Cache: STALE header", function()
                    local next_spy = spy.new(next)

                    sut:execute(cacheable_request_stale, next_spy)

                    local cache_key = create_key(cacheable_request)
                    assert.is_not_nil(fake_cache.values[cache_key])
                    assert.equal("STALE", fake_cache.values[cache_key].headers["X-Cache"])
                end)

                it("returns X-Cache-Age: 4000 header", function()
                    local next_spy = spy.new(next)

                    sut:execute(cacheable_request_stale, next_spy)

                    local cache_key = create_key(cacheable_request)
                    assert.is_not_nil(fake_cache.values[cache_key])
                    assert.equal("4000", fake_cache.values[cache_key].headers["X-Cache-Age"])
                end)

                it("returns X-Cache-TTL: ONE_DAY - 4000 header", function()
                    local next_spy = spy.new(next)

                    sut:execute(cacheable_request_stale, next_spy)

                    local cache_key = create_key(cacheable_request)
                    assert.is_not_nil(fake_cache.values[cache_key])
                    assert.equal(tostring(ONE_DAY - 4000), fake_cache.values[cache_key].headers["X-Cache-TTL"])
                end)

                it("returns X-Cache-TTS: 0 header", function()
                    local next_spy = spy.new(next)

                    sut:execute(cacheable_request_stale, next_spy)

                    local cache_key = create_key(cacheable_request)
                    assert.is_not_nil(fake_cache.values[cache_key])
                    assert.equal("0", fake_cache.values[cache_key].headers["X-Cache-TTS"])
                end)
            end)


            it("does not return cached value if expired", function()
                local next_spy = spy.new(next)

                sut:execute(cacheable_request, next_spy)

                local response = sut:execute(cacheable_request_expired, next_spy)

                assert.spy(next_spy).was_called(2)
            end)

            it("stores new cached value if expired", function()
                local next_spy = spy.new(next)

                sut:execute(cacheable_request, next_spy)

                local response = sut:execute(cacheable_request_expired, next_spy)

                local cache_key = create_key(cacheable_request)
                local cache_value = fake_cache.values[cache_key]
                assert.equal(cache_value.expires_at, cacheable_request_expired.timestamp + ONE_DAY)
                assert.equal(cache_value.stale_at, cacheable_request_expired.timestamp + ONE_HOUR)
            end)
        end)

        describe("when next returns a non-cacheable response", function()
            it("does not cache the response", function()
                sut:execute(non_cacheable_request, next)

                local cache_key = create_key(non_cacheable_request)
                assert.is_nil(fake_cache.values[cache_key])
            end)
        end)
    end)
end)
