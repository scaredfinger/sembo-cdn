local describe = require('busted').describe
local before_each = require('busted').before_each
local it = require('busted').it

local assert = require('luassert')
local spy = require('luassert.spy')

local Response = require('modules.http.response')
local Request = require('modules.http.request')

local InvalidateTagHandler = require('modules.surrogate.invalidate_tag_handler')

describe("InvalidateTagHandler", function()
    local fake_tags_provider
    local fake_cache_provider
    
    --- @type InvalidateTagHandler
    local sut

    before_each(function()
        fake_tags_provider = {
            get_keys_for_tag = function(self, tag)
                return {"cache:GET:example.com:/hotel/luxury-resort", "cache:GET:example.com:/hotel/luxury-resort/rooms"}
            end,
            del_by_tag = function(self, tag)
                return true
            end
        }
        
        fake_cache_provider = {
            del = function(self, key)
                return true
            end
        }
        
        sut = InvalidateTagHandler:new(fake_tags_provider, fake_cache_provider)
    end)

    it("can be instantiated", function()
        assert.is_not_nil(sut)
        assert.is_true(getmetatable(sut) == InvalidateTagHandler)
    end)

    it("stores tags provider on instantiation", function()
        assert.equal(fake_tags_provider, sut.tags_provider)
    end)

    it("stores cache provider on instantiation", function()
        assert.equal(fake_cache_provider, sut.cache_provider)
    end)

    describe("_extract_tag_from_path", function()
        it("extracts tag from valid path", function()
            local tag = sut:_extract_tag_from_path("/cache/tags/hotel:luxury-resort")
            assert.equal("hotel:luxury-resort", tag)
        end)

        it("extracts tag with special characters", function()
            local tag = sut:_extract_tag_from_path("/cache/tags/pricing:2024")
            assert.equal("pricing:2024", tag)
        end)

        it("returns nil for invalid path format", function()
            local tag = sut:_extract_tag_from_path("/cache/tags/")
            assert.is_nil(tag)
        end)

        it("returns nil for path with extra segments", function()
            local tag = sut:_extract_tag_from_path("/cache/tags/hotel:luxury-resort/extra")
            assert.is_nil(tag)
        end)

        it("returns nil for completely different path", function()
            local tag = sut:_extract_tag_from_path("/different/path")
            assert.is_nil(tag)
        end)

        it("returns nil for empty path", function()
            local tag = sut:_extract_tag_from_path("")
            assert.is_nil(tag)
        end)
    end)

    describe("execute", function()
        describe("method validation", function()
            it("returns 405 for GET request", function()
                local request = Request:new("GET", "/cache/tags/hotel:luxury-resort", {}, "", {}, "localhost")
                local response = sut:execute(request)

                assert.equal(405, response.status)
                assert.equal("Method Not Allowed", response.body)
                assert.equal("DELETE", response.headers["Allow"])
            end)

            it("returns 405 for POST request", function()
                local request = Request:new("POST", "/cache/tags/hotel:luxury-resort", {}, "", {}, "localhost")
                local response = sut:execute(request)

                assert.equal(405, response.status)
                assert.equal("Method Not Allowed", response.body)
                assert.equal("DELETE", response.headers["Allow"])
            end)

            it("returns 405 for PUT request", function()
                local request = Request:new("PUT", "/cache/tags/hotel:luxury-resort", {}, "", {}, "localhost")
                local response = sut:execute(request)

                assert.equal(405, response.status)
                assert.equal("Method Not Allowed", response.body)
                assert.equal("DELETE", response.headers["Allow"])
            end)
        end)

        describe("path validation", function()
            it("returns 400 for invalid path format", function()
                local request = Request:new("DELETE", "/cache/tags/", {}, "", {}, "localhost")
                local response = sut:execute(request)

                assert.equal(400, response.status)
                assert.equal("Bad Request: Invalid tag format", response.body)
                assert.equal("text/plain", response.headers["Content-Type"])
            end)

            it("returns 400 for empty tag", function()
                local request = Request:new("DELETE", "/cache/tags/", {}, "", {}, "localhost")
                local response = sut:execute(request)

                assert.equal(400, response.status)
                assert.equal("Bad Request: Invalid tag format", response.body)
            end)

            it("returns 400 for tag with whitespace", function()
                local request = Request:new("DELETE", "/cache/tags/hotel luxury", {}, "", {}, "localhost")
                local response = sut:execute(request)

                assert.equal(400, response.status)
                assert.equal("Bad Request: Invalid tag format", response.body)
            end)

            it("returns 400 for path with extra segments", function()
                local request = Request:new("DELETE", "/cache/tags/hotel:luxury-resort/extra", {}, "", {}, "localhost")
                local response = sut:execute(request)

                assert.equal(400, response.status)
                assert.equal("Bad Request: Invalid tag format", response.body)
            end)
        end)

        describe("successful invalidation", function()
            it("calls get_keys_for_tag on tags provider", function()
                local get_keys_spy = spy.on(fake_tags_provider, "get_keys_for_tag")
                local request = Request:new("DELETE", "/cache/tags/hotel:luxury-resort", {}, "", {}, "localhost")

                sut:execute(request)

                assert.spy(get_keys_spy).was_called(1)
                assert.spy(get_keys_spy).was_called_with(fake_tags_provider, "hotel:luxury-resort")
            end)

            it("calls del on cache provider for each cache key", function()
                local cache_del_spy = spy.on(fake_cache_provider, "del")
                local request = Request:new("DELETE", "/cache/tags/hotel:luxury-resort", {}, "", {}, "localhost")

                sut:execute(request)

                assert.spy(cache_del_spy).was_called(2)
                assert.spy(cache_del_spy).was_called_with(fake_cache_provider, "cache:GET:example.com:/hotel/luxury-resort")
                assert.spy(cache_del_spy).was_called_with(fake_cache_provider, "cache:GET:example.com:/hotel/luxury-resort/rooms")
            end)

            it("calls del_by_tag on tags provider after deleting cache keys", function()
                local del_by_tag_spy = spy.on(fake_tags_provider, "del_by_tag")
                local request = Request:new("DELETE", "/cache/tags/hotel:luxury-resort", {}, "", {}, "localhost")

                sut:execute(request)

                assert.spy(del_by_tag_spy).was_called(1)
                assert.spy(del_by_tag_spy).was_called_with(fake_tags_provider, "hotel:luxury-resort")
            end)

            it("returns 200 with count of invalidated entries", function()
                local request = Request:new("DELETE", "/cache/tags/hotel:luxury-resort", {}, "", {}, "localhost")
                local response = sut:execute(request)

                assert.equal(200, response.status)
                assert.equal("Invalidated 2 cache entries for tag 'hotel:luxury-resort'", response.body)
                assert.equal("no-cache", response.headers["Cache-Control"])
                assert.equal("text/plain", response.headers["Content-Type"])
            end)

            it("handles empty tag keys list", function()
                fake_tags_provider.get_keys_for_tag = function(self, tag)
                    return {}
                end
                local cache_del_spy = spy.on(fake_cache_provider, "del")
                local request = Request:new("DELETE", "/cache/tags/empty:tag", {}, "", {}, "localhost")

                local response = sut:execute(request)

                assert.spy(cache_del_spy).was_not_called()
                assert.equal(200, response.status)
                assert.equal("Invalidated 0 cache entries for tag 'empty:tag'", response.body)
            end)

            it("handles different tag formats", function()
                local del_by_tag_spy = spy.on(fake_tags_provider, "del_by_tag")
                local request = Request:new("DELETE", "/cache/tags/pricing:2024", {}, "", {}, "localhost")

                local response = sut:execute(request)

                assert.spy(del_by_tag_spy).was_called_with(fake_tags_provider, "pricing:2024")
                assert.equal(200, response.status)
            end)

            it("handles tag with hyphens and underscores", function()
                local del_by_tag_spy = spy.on(fake_tags_provider, "del_by_tag")
                local request = Request:new("DELETE", "/cache/tags/hotel_type:luxury-resort", {}, "", {}, "localhost")

                local response = sut:execute(request)

                assert.spy(del_by_tag_spy).was_called_with(fake_tags_provider, "hotel_type:luxury-resort")
                assert.equal(200, response.status)
            end)
        end)

        describe("provider failure", function()
            it("returns 500 when get_keys_for_tag returns nil", function()
                fake_tags_provider.get_keys_for_tag = function(self, tag)
                    return nil
                end

                local request = Request:new("DELETE", "/cache/tags/hotel:luxury-resort", {}, "", {}, "localhost")
                local response = sut:execute(request)

                assert.equal(500, response.status)
                assert.equal("Internal Server Error: Failed to retrieve cache keys for tag", response.body)
                assert.equal("text/plain", response.headers["Content-Type"])
            end)

            it("returns 500 when del_by_tag fails", function()
                fake_tags_provider.del_by_tag = function(self, tag)
                    return false
                end

                local request = Request:new("DELETE", "/cache/tags/hotel:luxury-resort", {}, "", {}, "localhost")
                local response = sut:execute(request)

                assert.equal(500, response.status)
                assert.equal("Internal Server Error: Failed to delete tag mappings", response.body)
                assert.equal("text/plain", response.headers["Content-Type"])
            end)

            it("continues with other cache keys when one cache deletion fails", function()
                local cache_del_call_count = 0
                fake_cache_provider.del = function(self, key)
                    cache_del_call_count = cache_del_call_count + 1
                    -- First call fails, second succeeds
                    return cache_del_call_count > 1
                end

                local request = Request:new("DELETE", "/cache/tags/hotel:luxury-resort", {}, "", {}, "localhost")
                local response = sut:execute(request)

                -- Should still proceed to delete tag mappings and return success
                assert.equal(2, cache_del_call_count)
                assert.equal(200, response.status)
                assert.equal("Invalidated 2 cache entries for tag 'hotel:luxury-resort'", response.body)
            end)
        end)

        describe("does not modify request", function()
            it("preserves request properties", function()
                local request = Request:new("DELETE", "/cache/tags/hotel:luxury-resort", {}, "", {}, "localhost")
                local original_method = request.method
                local original_path = request.path
                local original_host = request.host

                sut:execute(request)

                assert.equal(original_method, request.method)
                assert.equal(original_path, request.path)
                assert.equal(original_host, request.host)
            end)
        end)
    end)
end)
