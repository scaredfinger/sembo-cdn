local describe = require('busted').describe
local before_each = require('busted').before_each
local it = require('busted').it

local assert = require('luassert')
local spy = require('luassert.spy')

local Response = require('modules.http.response')
local Request = require('modules.http.request')
local parse_cache_control = require('modules.cache.cache_control_parser')

local CacheMiddleware = require('modules.cache.middleware')

-- Time constants
local ONE_HOUR = 3600
local ONE_DAY = 86400

describe("CachMiddleware", function()
    local cacheable_request = Request:new("GET", "/cacheable_request_test", {}, "", {}, "localhost")
    local cacheable_response = Response:new(200, "Cacheable response",
        { 
            ["Cache-Control"] = "public, max-age=" .. ONE_HOUR .. ", stale-while-revalidate=" .. ONE_DAY,
            ["Content-Type"] = "application/json"
        })

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

    --- Helper function to compare responses while ignoring middleware-added headers and locals
    --- @param expected_response Response The expected response (original or cached)
    --- @param actual_response Response The actual response from middleware
    local function assert_response_content_equal(expected_response, actual_response)
        assert.equal(expected_response.body, actual_response.body)
        assert.equal(expected_response.status, actual_response.status)
        assert.equal(expected_response.headers["Cache-Control"], actual_response.headers["Cache-Control"])
        assert.equal(expected_response.headers["Content-Type"], actual_response.headers["Content-Type"])
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

                assert_response_content_equal(cacheable_response, response)
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

                local response = sut:execute(cacheable_request, next_spy)

                local cache_key = create_key(cacheable_request)
                assert.is_not_nil(fake_cache.values[cache_key])
                assert.equal(tostring(ONE_DAY), response.headers["X-Cache-TTL"])
            end)

            it("returns X-Cache-TTS: ONE_HOUR header", function()
                local next_spy = spy.new(next)

                local response = sut:execute(cacheable_request, next_spy)

                local cache_key = create_key(cacheable_request)
                assert.is_not_nil(fake_cache.values[cache_key])
                assert.equal(tostring(ONE_HOUR), response.headers["X-Cache-TTS"])
            end)

            it("sets cache_state to miss in locals", function()
                local next_spy = spy.new(next)

                local response = sut:execute(cacheable_request, next_spy)

                assert.is_not_nil(response)
                assert.equal("miss", response.locals.cache_state)
            end)

            it("sets cache_ttl to 0 in locals", function()
                local next_spy = spy.new(next)

                local response = sut:execute(cacheable_request, next_spy)

                assert.is_not_nil(response)
                assert.equal(0, response.locals.cache_ttl)
            end)

            it("sets cache_tts to 0 in locals", function()
                local next_spy = spy.new(next)

                local response = sut:execute(cacheable_request, next_spy)

                assert.is_not_nil(response)
                assert.equal(0, response.locals.cache_tts)
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
                    assert_response_content_equal(cache_value, response)
                end)

                it("does not call next again", function()
                    local next_spy = spy.new(next)

                    sut:execute(cacheable_request, next_spy)
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

                it("sets cache_state to hit in locals", function()
                    local next_spy = spy.new(next)

                    local response = sut:execute(cacheable_request, next_spy)

                    assert.is_not_nil(response)
                    assert.equal("hit", response.locals.cache_state)
                end)

                it("sets cache_ttl to ONE_DAY in locals", function()
                    local next_spy = spy.new(next)

                    local response = sut:execute(cacheable_request, next_spy)

                    assert.is_not_nil(response)
                    assert.equal(ONE_DAY, response.locals.cache_ttl)
                end)

                it("sets cache_tts to ONE_HOUR in locals", function()
                    local next_spy = spy.new(next)

                    local response = sut:execute(cacheable_request, next_spy)

                    assert.is_not_nil(response)
                    assert.equal(ONE_HOUR, response.locals.cache_tts)
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
                    
                    -- Compare body, status and original headers (not middleware-added headers)
                    assert_response_content_equal(cache_value, response)
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
                    assert.equal(cache_value.expired_at, cacheable_request.timestamp + ONE_DAY)
                end)

                it("defers the cache update", function()
                    local next_spy = spy.new(next)
                    sut:execute(cacheable_request_stale, next_spy)

                    deferred()

                    local cache_key = create_key(cacheable_request)
                    local cache_value = fake_cache.values[cache_key]
                    assert.equal(cache_value.stale_at, cacheable_request_stale.timestamp + ONE_HOUR)
                    assert.equal(cache_value.expired_at, cacheable_request_stale.timestamp + ONE_DAY)
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

                    local response = sut:execute(cacheable_request_stale, next_spy)

                    local cache_key = create_key(cacheable_request)
                    assert.is_not_nil(fake_cache.values[cache_key])
                    assert.equal(tostring(ONE_DAY - 4000), response.headers['X-Cache-TTL'])
                end)

                it("returns X-Cache-TTS: 0 header", function()
                    local next_spy = spy.new(next)

                    local response = sut:execute(cacheable_request_stale, next_spy)

                    local cache_key = create_key(cacheable_request)
                    assert.is_not_nil(fake_cache.values[cache_key])
                    assert.equal(tostring(0), response.headers['X-Cache-TTS'])
                end)

                it("sets cache_state to stale in locals", function()
                    local next_spy = spy.new(next)

                    local response = sut:execute(cacheable_request_stale, next_spy)

                    assert.is_not_nil(response)
                    assert.equal("stale", response.locals.cache_state)
                end)

                it("sets cache_ttl to ONE_DAY - 4000 in locals", function()
                    local next_spy = spy.new(next)

                    local response = sut:execute(cacheable_request_stale, next_spy)

                    assert.is_not_nil(response)
                    assert.equal(ONE_DAY - 4000, response.locals.cache_ttl)
                end)

                it("sets cache_tts to 0 in locals", function()
                    local next_spy = spy.new(next)

                    local response = sut:execute(cacheable_request_stale, next_spy)

                    assert.is_not_nil(response)
                    assert.equal(0, response.locals.cache_tts)
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
                assert.equal(cache_value.expired_at, cacheable_request_expired.timestamp + ONE_DAY)
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

    describe("when cached response has locals", function()
                local cacheable_request_with_locals = Request:new("GET", "/cacheable_with_locals", {}, "", {}, "localhost")
                local cacheable_response_with_locals = Response:new(200, "Response with locals",
                    { 
                        ["Cache-Control"] = "public, max-age=" .. ONE_HOUR .. ", stale-while-revalidate=" .. ONE_DAY,
                        ["Content-Type"] = "application/json"
                    },
                    {
                        user_id = "12345",
                        session_data = { authenticated = true, role = "admin" },
                        request_id = "req-abc-123"
                    })

                local function next_with_locals(request)
                    if request == cacheable_request_with_locals then
                        return cacheable_response_with_locals
                    end
                    return next(request)
                end

                before_each(function()
                    -- First request to cache the response with locals
                    sut:execute(cacheable_request_with_locals, next_with_locals)
                end)

                it("preserves cached locals in response", function()
                    local response = sut:execute(cacheable_request_with_locals, next_with_locals)

                    -- Check that all original locals are preserved
                    assert.is_not_nil(response.locals)
                    assert.equal("12345", response.locals.user_id)
                    assert.equal(true, response.locals.session_data.authenticated)
                    assert.equal("admin", response.locals.session_data.role)
                    assert.equal("req-abc-123", response.locals.request_id)
                end)

                it("includes both cached locals and cache-specific locals", function()
                    local response = sut:execute(cacheable_request_with_locals, next_with_locals)

                    -- Check original locals are preserved
                    assert.equal("12345", response.locals.user_id)
                    assert.equal("req-abc-123", response.locals.request_id)
                    
                    -- Check cache-specific locals are added
                    assert.equal("hit", response.locals.cache_state)
                    assert.equal(ONE_DAY, response.locals.cache_ttl)
                    assert.equal(ONE_HOUR, response.locals.cache_tts)
                    assert.is_number(response.locals.cache_age)
                end)

                it("preserves nested objects in cached locals", function()
                    local response = sut:execute(cacheable_request_with_locals, next_with_locals)

                    assert.is_table(response.locals.session_data)
                    assert.equal(true, response.locals.session_data.authenticated)
                    assert.equal("admin", response.locals.session_data.role)
                end)
            end)

            describe("when stale cached response has locals", function()
                local cacheable_request_stale_with_locals = Request:new("GET", "/cacheable_with_locals", {}, "", {},
                    "localhost", os.time() + 4000)
                local cacheable_response_with_locals = Response:new(200, "Response with locals",
                    { 
                        ["Cache-Control"] = "public, max-age=" .. ONE_HOUR .. ", stale-while-revalidate=" .. ONE_DAY,
                        ["Content-Type"] = "application/json"
                    },
                    {
                        user_id = "12345",
                        session_data = { authenticated = true, role = "admin" },
                        request_id = "req-abc-123"
                    })

                local function next_with_locals(request)
                    if request.path == "/cacheable_with_locals" then
                        return cacheable_response_with_locals
                    end
                    return next(request)
                end

                before_each(function()
                    -- First request to cache the response with locals using original timestamp
                    local original_request = Request:new("GET", "/cacheable_with_locals", {}, "", {}, "localhost")
                    sut:execute(original_request, next_with_locals)
                end)

                it("preserves cached locals in stale response", function()
                    local response = sut:execute(cacheable_request_stale_with_locals, next_with_locals)

                    -- Check that all original locals are preserved
                    assert.is_not_nil(response.locals)
                    assert.equal("12345", response.locals.user_id)
                    assert.equal(true, response.locals.session_data.authenticated)
                    assert.equal("admin", response.locals.session_data.role)
                    assert.equal("req-abc-123", response.locals.request_id)
                end)

                it("includes both cached locals and stale cache-specific locals", function()
                    local response = sut:execute(cacheable_request_stale_with_locals, next_with_locals)

                    -- Check original locals are preserved
                    assert.equal("12345", response.locals.user_id)
                    assert.equal("req-abc-123", response.locals.request_id)
                    
                    -- Check cache-specific locals are added for stale response
                    assert.equal("stale", response.locals.cache_state)
                    assert.equal(ONE_DAY - 4000, response.locals.cache_ttl)
                    assert.equal(0, response.locals.cache_tts)
                end)
            end)

            describe("when cached response has no locals", function()
                local cacheable_request_no_locals = Request:new("GET", "/cacheable_no_locals", {}, "", {}, "localhost")
                local cacheable_response_no_locals = Response:new(200, "Response without locals",
                    { 
                        ["Cache-Control"] = "public, max-age=" .. ONE_HOUR .. ", stale-while-revalidate=" .. ONE_DAY,
                        ["Content-Type"] = "application/json"
                    })
                    -- Note: No locals parameter passed, so Response will use empty table

                local function next_no_locals(request)
                    if request == cacheable_request_no_locals then
                        return cacheable_response_no_locals
                    end
                    return next(request)
                end

                before_each(function()
                    -- First request to cache the response without locals
                    sut:execute(cacheable_request_no_locals, next_no_locals)
                end)

                it("still includes cache-specific locals even when no original locals", function()
                    local response = sut:execute(cacheable_request_no_locals, next_no_locals)

                    -- Check that cache-specific locals are added
                    assert.is_not_nil(response.locals)
                    assert.equal("hit", response.locals.cache_state)
                    assert.equal(ONE_DAY, response.locals.cache_ttl)
                    assert.equal(ONE_HOUR, response.locals.cache_tts)
                    assert.is_number(response.locals.cache_age)
                end)

                it("has empty locals table if no cached locals exist", function()
                    local response = sut:execute(cacheable_request_no_locals, next_no_locals)

                    -- Should have cache-specific locals but no other custom locals
                    assert.is_table(response.locals)
                    
                    -- Count the number of keys (should only be cache-related)
                    local count = 0
                    for _ in pairs(response.locals) do
                        count = count + 1
                    end
                    assert.equal(4, count) -- cache_state, cache_age, cache_ttl, cache_tts
                end)
            end)
end)
