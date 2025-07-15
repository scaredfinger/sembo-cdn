local describe = require('busted').describe
local before_each = require('busted').before_each
local it = require('busted').it

local assert = require('luassert')
local spy = require('luassert.spy')

local Response = require('modules.http.response')
local Request = require('modules.http.request')
local CompressionMiddleware = require('modules.compression.middleware')

describe("CompressionMiddleware", function()
    local fake_gzip_codec
    local fake_brotli_codec
    local fake_deflate_codec
    local sut

    local test_body = "This is a test response body that should be compressed"
    local compressed_gzip = "gzip_compressed_data"
    local compressed_brotli = "brotli_compressed_data"
    local compressed_deflate = "deflate_compressed_data"

    before_each(function()
        fake_gzip_codec = {
            encode = spy.new(function(data)
                return compressed_gzip
            end),
            decode = spy.new(function(data)
                return test_body
            end)
        }

        fake_brotli_codec = {
            encode = spy.new(function(data)
                return compressed_brotli
            end),
            decode = spy.new(function(data)
                return test_body
            end)
        }

        fake_deflate_codec = {
            encode = spy.new(function(data)
                return compressed_deflate
            end),
            decode = spy.new(function(data)
                return test_body
            end)
        }

        sut = CompressionMiddleware:new(fake_gzip_codec, fake_brotli_codec, fake_deflate_codec)
    end)

    it("can be instantiated", function()
        assert.is_not_nil(sut)
        assert.is_true(getmetatable(sut) == CompressionMiddleware)
    end)

    describe("when response has no body", function()
        local request = Request:new("GET", "/test", { ["Accept-Encoding"] = "gzip" }, "", {}, "localhost")
        local response_no_body = Response:new(200, "", { ["Content-Type"] = "text/html" })

        local function next(req)
            return response_no_body
        end

        it("returns response unchanged", function()
            local result = sut:execute(request, next)

            assert.equal(response_no_body, result)
            assert.spy(fake_gzip_codec.encode).was_not_called()
        end)
    end)

    describe("when response has empty body", function()
        local request = Request:new("GET", "/test", { ["Accept-Encoding"] = "gzip" }, "", {}, "localhost")
        local response_empty_body = Response:new(200, "", { ["Content-Type"] = "text/html" })

        local function next(req)
            return response_empty_body
        end

        it("returns response unchanged", function()
            local result = sut:execute(request, next)

            assert.equal(response_empty_body, result)
            assert.spy(fake_gzip_codec.encode).was_not_called()
        end)
    end)

    describe("when content type is not compressible", function()
        local request = Request:new("GET", "/test", { ["Accept-Encoding"] = "gzip" }, "", {}, "localhost")
        local response_binary = Response:new(200, test_body, { ["Content-Type"] = "image/jpeg" })

        local function next(req)
            return response_binary
        end

        it("returns response unchanged", function()
            local result = sut:execute(request, next)

            assert.equal(response_binary, result)
            assert.spy(fake_gzip_codec.encode).was_not_called()
        end)
    end)

    describe("when request has no Accept-Encoding header", function()
        local request = Request:new("GET", "/test", {}, "", {}, "localhost")
        local response = Response:new(200, test_body, { ["Content-Type"] = "text/html" })

        local function next(req)
            return response
        end

        it("returns response unchanged", function()
            local result = sut:execute(request, next)

            assert.equal(response, result)
            assert.spy(fake_gzip_codec.encode).was_not_called()
        end)
    end)

    describe("when response is already compressed with preferred encoding", function()
        local request = Request:new("GET", "/test", { ["Accept-Encoding"] = "gzip" }, "", {}, "localhost")
        local response = Response:new(200, compressed_gzip, { ["Content-Type"] = "text/html", ["Content-Encoding"] = "gzip" })

        local function next(req)
            return response
        end

        it("returns response unchanged", function()
            local result = sut:execute(request, next)

            assert.equal(response, result)
            assert.spy(fake_gzip_codec.encode).was_not_called()
            assert.spy(fake_gzip_codec.decode).was_not_called()
        end)
    end)

    describe("when response is uncompressed and client accepts gzip", function()
        local request = Request:new("GET", "/test", { ["Accept-Encoding"] = "gzip" }, "", {}, "localhost")
        local response = Response:new(200, test_body, { ["Content-Type"] = "text/html" })

        local function next(req)
            return response
        end

        it("compresses with gzip", function()
            local result = sut:execute(request, next)

            assert.spy(fake_gzip_codec.encode).was_called_with(test_body)
            assert.equal(compressed_gzip, result.body)
            assert.equal("gzip", result.headers["Content-Encoding"])
            assert.equal(tostring(#compressed_gzip), result.headers["Content-Length"])
            assert.equal("Accept-Encoding", result.headers["Vary"])
        end)

        it("sets compression locals", function()
            local result = sut:execute(request, next)

            assert.equal("gzip", result.locals.compression_encoding)
            assert.is_nil(result.locals.compression_original_encoding)
            assert.is_number(result.locals.compression_ratio)
        end)
    end)

    describe("when response is uncompressed and client accepts brotli", function()
        local request = Request:new("GET", "/test", { ["Accept-Encoding"] = "br" }, "", {}, "localhost")
        local response = Response:new(200, test_body, { ["Content-Type"] = "application/json" })

        local function next(req)
            return response
        end

        it("compresses with brotli", function()
            local result = sut:execute(request, next)

            assert.spy(fake_brotli_codec.encode).was_called_with(test_body)
            assert.equal(compressed_brotli, result.body)
            assert.equal("br", result.headers["Content-Encoding"])
        end)
    end)

    describe("when response is uncompressed and client accepts deflate", function()
        local request = Request:new("GET", "/test", { ["Accept-Encoding"] = "deflate" }, "", {}, "localhost")
        local response = Response:new(200, test_body, { ["Content-Type"] = "application/json" })

        local function next(req)
            return response
        end

        it("compresses with deflate", function()
            local result = sut:execute(request, next)

            assert.spy(fake_deflate_codec.encode).was_called_with(test_body)
            assert.equal(compressed_deflate, result.body)
            assert.equal("deflate", result.headers["Content-Encoding"])
        end)
    end)

    describe("when response is gzip compressed and client prefers brotli", function()
        local request = Request:new("GET", "/test", { ["Accept-Encoding"] = "br" }, "", {}, "localhost")
        local response = Response:new(200, compressed_gzip, { ["Content-Type"] = "text/html", ["Content-Encoding"] = "gzip" })

        local function next(req)
            return response
        end

        it("decompresses gzip and compresses with brotli", function()
            local result = sut:execute(request, next)

            assert.spy(fake_gzip_codec.decode).was_called_with(compressed_gzip)
            assert.spy(fake_brotli_codec.encode).was_called_with(test_body)
            assert.equal(compressed_brotli, result.body)
            assert.equal("br", result.headers["Content-Encoding"])
        end)

        it("sets compression locals with original encoding", function()
            local result = sut:execute(request, next)

            assert.equal("br", result.locals.compression_encoding)
            assert.equal("gzip", result.locals.compression_original_encoding)
            assert.is_number(result.locals.compression_ratio)
        end)
    end)

    describe("when response is deflate compressed and client accepts multiple encodings", function()
        local request = Request:new("GET", "/test", { ["Accept-Encoding"] = "gzip, br, deflate" }, "", {}, "localhost")
        local response = Response:new(200, compressed_deflate, { ["Content-Type"] = "text/html", ["Content-Encoding"] = "deflate" })

        local function next(req)
            return response
        end

        it("keeps deflate encoding due to upstream priority", function()
            local result = sut:execute(request, next)

            assert.equal(response, result)
            assert.spy(fake_deflate_codec.decode).was_not_called()
            assert.spy(fake_brotli_codec.encode).was_not_called()
        end)
    end)

    describe("when response is brotli compressed and client prefers gzip", function()
        local request = Request:new("GET", "/test", { ["Accept-Encoding"] = "gzip" }, "", {}, "localhost")
        local response = Response:new(200, compressed_brotli, { ["Content-Type"] = "application/javascript", ["Content-Encoding"] = "br" })

        local function next(req)
            return response
        end

        it("decompresses brotli and compresses with gzip", function()
            local result = sut:execute(request, next)

            assert.spy(fake_brotli_codec.decode).was_called_with(compressed_brotli)
            assert.spy(fake_gzip_codec.encode).was_called_with(test_body)
            assert.equal(compressed_gzip, result.body)
            assert.equal("gzip", result.headers["Content-Encoding"])
        end)
    end)

    describe("when response is compressed and client accepts plain", function()
        local request = Request:new("GET", "/test", {}, "", {}, "localhost")
        local response = Response:new(200, compressed_gzip, { ["Content-Type"] = "text/html", ["Content-Encoding"] = "gzip" })

        local function next(req)
            return response
        end

        it("decompresses to plain text", function()
            local result = sut:execute(request, next)

            assert.spy(fake_gzip_codec.decode).was_called_with(compressed_gzip)
            assert.equal(test_body, result.body)
            assert.is_nil(result.headers["Content-Encoding"])
        end)

        it("sets compression locals", function()
            local result = sut:execute(request, next)

            assert.is_nil(result.locals.compression_encoding)
            assert.equal("gzip", result.locals.compression_original_encoding)
            assert.is_number(result.locals.compression_ratio)
        end)
    end)

    describe("when Accept-Encoding contains multiple encodings", function()
        local request = Request:new("GET", "/test", { ["Accept-Encoding"] = "gzip, br, deflate" }, "", {}, "localhost")
        local response = Response:new(200, test_body, { ["Content-Type"] = "text/plain" })

        local function next(req)
            return response
        end

        it("prefers br over gzip over deflate", function()
            local result = sut:execute(request, next)

            assert.spy(fake_brotli_codec.encode).was_called()
            assert.equal("br", result.headers["Content-Encoding"])
        end)
    end)

    describe("when Accept-Encoding contains only deflate and gzip", function()
        local request = Request:new("GET", "/test", { ["Accept-Encoding"] = "gzip, deflate" }, "", {}, "localhost")
        local response = Response:new(200, test_body, { ["Content-Type"] = "text/plain" })

        local function next(req)
            return response
        end

        it("prefers gzip over deflate", function()
            local result = sut:execute(request, next)

            assert.spy(fake_gzip_codec.encode).was_called()
            assert.equal("gzip", result.headers["Content-Encoding"])
        end)
    end)

    describe("when Accept-Encoding has quality values", function()
        local request = Request:new("GET", "/test", { ["Accept-Encoding"] = "gzip;q=0.8, br;q=0.9" }, "", {}, "localhost")
        local response = Response:new(200, test_body, { ["Content-Type"] = "text/css" })

        local function next(req)
            return response
        end

        it("still uses preference order regardless of quality", function()
            local result = sut:execute(request, next)

            assert.spy(fake_brotli_codec.encode).was_called()
            assert.equal("br", result.headers["Content-Encoding"])
        end)
    end)

    describe("when Accept-Encoding contains unsupported encoding", function()
        local request = Request:new("GET", "/test", { ["Accept-Encoding"] = "identity, compress" }, "", {}, "localhost")
        local response = Response:new(200, test_body, { ["Content-Type"] = "text/html" })

        local function next(req)
            return response
        end

        it("returns response unchanged", function()
            local result = sut:execute(request, next)

            assert.equal(response, result)
            assert.spy(fake_gzip_codec.encode).was_not_called()
            assert.spy(fake_brotli_codec.encode).was_not_called()
        end)
    end)

    describe("when response has existing locals", function()
        local request = Request:new("GET", "/test", { ["Accept-Encoding"] = "gzip" }, "", {}, "localhost")
        local response_with_locals = Response:new(200, test_body, { ["Content-Type"] = "text/html" })
        response_with_locals.locals.request_id = "req-123"
        response_with_locals.locals.user_id = "user-456"

        local function next(req)
            return response_with_locals
        end

        it("preserves existing locals and adds compression locals", function()
            local result = sut:execute(request, next)

            assert.equal("req-123", result.locals.request_id)
            assert.equal("user-456", result.locals.user_id)
            assert.equal("gzip", result.locals.compression_encoding)
            assert.is_number(result.locals.compression_ratio)
        end)
    end)

    describe("when content encoding is invalid", function()
        local request = Request:new("GET", "/test", { ["Accept-Encoding"] = "gzip" }, "", {}, "localhost")
        local response = Response:new(200, test_body, { ["Content-Type"] = "text/html", ["Content-Encoding"] = "unsupported" })

        local function next(req)
            return response
        end

        it("treats as uncompressed and compresses with preferred encoding", function()
            local result = sut:execute(request, next)

            assert.spy(fake_gzip_codec.encode).was_called_with(test_body)
            assert.equal(compressed_gzip, result.body)
            assert.equal("gzip", result.headers["Content-Encoding"])
        end)
    end)

    describe("when response is already compressed with non-preferred encoding", function()
        local request = Request:new("GET", "/test", { ["Accept-Encoding"] = "gzip, br" }, "", {}, "localhost")
        local response = Response:new(200, compressed_gzip, { ["Content-Type"] = "application/xml", ["Content-Encoding"] = "gzip" })

        local function next(req)
            return response
        end

        it("keeps current encoding if acceptable", function()
            local result = sut:execute(request, next)

            assert.equal(response, result)
            assert.spy(fake_gzip_codec.decode).was_not_called()
            assert.spy(fake_brotli_codec.encode).was_not_called()
        end)
    end)
end)
