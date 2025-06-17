local describe = require('busted').describe
local before_each = require('busted').before_each
local it = require('busted').it
local assert = require('luassert')

local CacheControlParser = require("modules.cache.cache_control_parser")

describe("CacheControlParser", function()
    local parser

    before_each(function()
        parser = CacheControlParser
    end)

    describe("parse", function()
        it("should parse no-cache directive", function()
            local result = parser:parse("no-cache")
            assert.is_true(result.no_cache)
            assert.is_false(result.no_store)
            assert.is_false(result.private)
            assert.is_false(result.public)
        end)

        it("should parse no-store directive", function()
            local result = parser:parse("no-store")
            assert.is_true(result.no_store)
            assert.is_false(result.no_cache)
        end)

        it("should parse private directive", function()
            local result = parser:parse("private")
            assert.is_true(result.private)
            assert.is_false(result.public)
        end)

        it("should parse public directive", function()
            local result = parser:parse("public")
            assert.is_true(result.public)
            assert.is_false(result.private)
        end)

        it("should parse max-age directive with value", function()
            local result = parser:parse("max-age=3600")
            assert.are.equal(3600, result.max_age)
        end)

        it("should parse stale-while-revalidate directive with value", function()
            local result = parser:parse("stale-while-revalidate=300")
            assert.are.equal(300, result.stale_while_revalidate)
        end)

        it("should parse surrogate-key directive with value", function()
            local result = parser:parse("surrogate-key=abc123")
            assert.are.equal("abc123", result.surrogate_key[0])
        end)

        it("should parse surrogate-key directive with several values", function()
            local result = parser:parse("surrogate-key=abc123 def456 ghi789")
            assert.are.equal("abc123", result.surrogate_key[0])
            assert.are.equal("def456", result.surrogate_key[1])
            assert.are.equal("ghi789", result.surrogate_key[2])
        end)

        it("should parse multiple directives", function()
            local result = parser:parse("no-cache, max-age=3600, private")
            assert.is_true(result.no_cache)
            assert.are.equal(3600, result.max_age)
            assert.is_true(result.private)
        end)

        it("should handle whitespace around directives", function()
            local result = parser:parse(" no-cache , max-age = 1800 , public ")
            assert.is_true(result.no_cache)
            assert.are.equal(1800, result.max_age)
            assert.is_true(result.public)
        end)

        it("should handle empty header", function()
            local result = parser:parse("")
            assert.is_false(result.no_cache)
            assert.is_false(result.no_store)
            assert.are.equal(0, result.max_age)
        end)

        it("should handle header with only commas", function()
            local result = parser:parse(",,, ")
            assert.is_false(result.no_cache)
            assert.is_false(result.no_store)
        end)

        it("should ignore malformed directives", function()
            local result = parser:parse("no-cache, invalid-directive, max-age=600")
            assert.is_true(result.no_cache)
            assert.are.equal(600, result.max_age)
        end)

        it("should handle directives without values", function()
            local result = parser:parse("no-cache=, private=")
            assert.are.equal(true, result.no_cache)
            assert.are.equal(true, result.private)
        end)

        it("should handle case insensitive directive names", function()
            local result = parser:parse("NO-CACHE, Max-Age=1200, PRIVATE")
            assert.is_true(result.no_cache)
            assert.are.equal(1200, result.max_age)
            assert.is_true(result.private)
        end)

        it("should preserve original structure for known directives", function()
            local result = parser:parse("no-cache")
            assert.is_not_nil(result.no_cache)
            assert.is_not_nil(result.no_store)
            assert.is_not_nil(result.max_age)
            assert.is_not_nil(result.private)
            assert.is_not_nil(result.public)
            assert.is_not_nil(result.stale_while_revalidate)
            assert.is_not_nil(result.surrogate_key)
        end)

        it("should handle complex real-world header", function()
            local result = parser:parse("public, max-age=31536000, stale-while-revalidate=86400, surrogate-key=homepage")
            assert.is_true(result.public)
            assert.are.equal(31536000, result.max_age)
            assert.are.equal(86400, result.stale_while_revalidate)
            assert.are.equal("homepage", result.surrogate_key[0])
        end)
    end)
end)
