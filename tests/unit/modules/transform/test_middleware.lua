local describe = require('busted').describe
local before_each = require('busted').before_each
local it = require('busted').it

local assert = require('luassert')
local spy = require('luassert.spy')

local Request = require('modules.http.request')
local Response = require('modules.http.response')

local TransformMiddleware = require('modules.transform.middleware')

describe("TransformMiddleware", function()
    local test_request = Request:new("GET", "/test/path", {
        ["Content-Type"] = "application/json",
        ["Authorization"] = "Bearer token123"
    }, '{"key": "value"}', { param1 = "value1" }, "localhost", 1234567890)
    
    local test_response = Response:new(200, "Test response", {})

    --- @type fun(request: Request): Response
    local function next(request)
        return test_response
    end

    --- @type TransformMiddleware
    local sut

    describe("constructor", function()
        it("can be instantiated with transform function", function()
            local transform_fn = function(request) return request end
            sut = TransformMiddleware:new(transform_fn)
            
            assert.is_not_nil(sut)
            assert.is_true(getmetatable(sut) == TransformMiddleware)
            assert.equal(transform_fn, sut.transform_fn)
        end)
    end)

    describe("request cloning behavior", function()
        local transform_fn = function(request) return request end
        
        before_each(function()
            sut = TransformMiddleware:new(transform_fn)
        end)

        it("does not modify original request when transform function modifies the request", function()
            local transform_fn = function(request)
                -- Modify the request passed to transform function
                request.method = "POST"
                request.path = "/modified/path"
                request.headers["New-Header"] = "new-value"
                request.query.new_param = "new_value"
                return request
            end
            sut = TransformMiddleware:new(transform_fn)
            
            local original_method = test_request.method
            local original_path = test_request.path
            local original_headers_count = 0
            for _ in pairs(test_request.headers) do
                original_headers_count = original_headers_count + 1
            end

            sut:execute(test_request, next)

            -- Original request should be unchanged
            assert.equal(original_method, test_request.method)
            assert.equal(original_path, test_request.path)
            assert.is_nil(test_request.headers["New-Header"])
            assert.is_nil(test_request.query.new_param)
            
            local new_headers_count = 0
            for _ in pairs(test_request.headers) do
                new_headers_count = new_headers_count + 1
            end
            assert.equal(original_headers_count, new_headers_count)
        end)
    end)

    describe("execute", function()
        it("calls next middleware with transformed request", function()
            local transform_fn = spy.new(function(request)
                request.path = "/transformed/path"
                return request
            end)
            sut = TransformMiddleware:new(transform_fn)
            local next_spy = spy.new(next)

            sut:execute(test_request, next_spy)

            assert.spy(transform_fn).was_called(1)
            assert.spy(next_spy).was_called(1)
            
            -- Check that next was called with the transformed request
            local transformed_request = next_spy.calls[1].refs[1]
            assert.equal("/transformed/path", transformed_request.path)
        end)

        it("does not modify the original request", function()
            local transform_fn = function(request)
                request.method = "POST"
                request.path = "/transformed/path"
                request.headers["New-Header"] = "new-value"
                return request
            end
            sut = TransformMiddleware:new(transform_fn)
            
            local original_method = test_request.method
            local original_path = test_request.path
            local original_headers_count = 0
            for _ in pairs(test_request.headers) do
                original_headers_count = original_headers_count + 1
            end

            sut:execute(test_request, next)

            -- Original request should be unchanged
            assert.equal(original_method, test_request.method)
            assert.equal(original_path, test_request.path)
            assert.is_nil(test_request.headers["New-Header"])
            
            local new_headers_count = 0
            for _ in pairs(test_request.headers) do
                new_headers_count = new_headers_count + 1
            end
            assert.equal(original_headers_count, new_headers_count)
        end)

        it("returns the response from next middleware", function()
            local transform_fn = function(request) return request end
            sut = TransformMiddleware:new(transform_fn)
            
            local response = sut:execute(test_request, next)
            
            assert.equal(test_response, response)
        end)

        it("passes cloned request to transform function", function()
            local passed_request = nil
            local transform_fn = function(request)
                passed_request = request
                return request
            end
            sut = TransformMiddleware:new(transform_fn)

            sut:execute(test_request, next)

            assert.is_not_nil(passed_request)
            assert.are_not.equal(test_request, passed_request)
            -- But should have same content
            if passed_request then
                assert.equal(test_request.method, passed_request.method)
                assert.equal(test_request.path, passed_request.path)
            end
        end)

        it("handles transform function that adds headers", function()
            local transform_fn = function(request)
                request.headers["X-Custom-Header"] = "custom-value"
                request.headers["X-Request-ID"] = "req-123"
                return request
            end
            sut = TransformMiddleware:new(transform_fn)
            local next_spy = spy.new(next)

            sut:execute(test_request, next_spy)

            local transformed_request = next_spy.calls[1].refs[1]
            assert.equal("custom-value", transformed_request.headers["X-Custom-Header"])
            assert.equal("req-123", transformed_request.headers["X-Request-ID"])
            
            -- Original should not have these headers
            assert.is_nil(test_request.headers["X-Custom-Header"])
            assert.is_nil(test_request.headers["X-Request-ID"])
        end)

        it("handles transform function that modifies query parameters", function()
            local transform_fn = function(request)
                request.query.transformed = "true"
                request.query.param1 = "modified_value"
                return request
            end
            sut = TransformMiddleware:new(transform_fn)
            local next_spy = spy.new(next)

            sut:execute(test_request, next_spy)

            local transformed_request = next_spy.calls[1].refs[1]
            assert.equal("true", transformed_request.query.transformed)
            assert.equal("modified_value", transformed_request.query.param1)
            
            -- Original should not be modified
            assert.is_nil(test_request.query.transformed)
            assert.equal("value1", test_request.query.param1)
        end)

        it("handles transform function that changes method and body", function()
            local transform_fn = function(request)
                request.method = "POST"
                request.body = '{"transformed": true}'
                return request
            end
            sut = TransformMiddleware:new(transform_fn)
            local next_spy = spy.new(next)

            sut:execute(test_request, next_spy)

            local transformed_request = next_spy.calls[1].refs[1]
            assert.equal("POST", transformed_request.method)
            assert.equal('{"transformed": true}', transformed_request.body)
            
            -- Original should not be modified
            assert.equal("GET", test_request.method)
            assert.equal('{"key": "value"}', test_request.body)
        end)
    end)
end)
