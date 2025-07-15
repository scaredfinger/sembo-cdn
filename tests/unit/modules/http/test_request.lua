local describe = require('busted').describe
local before_each = require('busted').before_each
local it = require('busted').it
local assert = require('luassert')

local Request = require('modules.http.request')

describe("Request", function()
    local test_request

    before_each(function()
        test_request = Request:new("GET", "/test/path", {
            ["Content-Type"] = "application/json",
            ["Authorization"] = "Bearer token123"
        }, '{"key": "value"}', { param1 = "value1" }, "localhost", 1234567890)
    end)

    describe("clone", function()
        it("creates a new request instance", function()
            local cloned_request = test_request:clone()
            
            assert.is_not_nil(cloned_request)
            assert.are_not.equal(test_request, cloned_request)
            assert.is_true(getmetatable(cloned_request) == Request)
        end)

        it("preserves all request properties", function()
            local cloned_request = test_request:clone()
            
            assert.equal(test_request.method, cloned_request.method)
            assert.equal(test_request.path, cloned_request.path)
            assert.equal(test_request.body, cloned_request.body)
            assert.equal(test_request.host, cloned_request.host)
            assert.equal(test_request.timestamp, cloned_request.timestamp)
        end)

        it("creates shallow copies of headers", function()
            local cloned_request = test_request:clone()
            
            -- Headers should have same values but be different objects
            assert.are_not.equal(test_request.headers, cloned_request.headers)
            assert.equal(test_request.headers["Content-Type"], cloned_request.headers["Content-Type"])
            assert.equal(test_request.headers["Authorization"], cloned_request.headers["Authorization"])
        end)

        it("creates shallow copies of query parameters", function()
            local cloned_request = test_request:clone()
            
            -- Query should have same values but be different objects
            assert.are_not.equal(test_request.query, cloned_request.query)
            assert.equal(test_request.query.param1, cloned_request.query.param1)
        end)

        it("modifications to cloned request do not affect original", function()
            local cloned_request = test_request:clone()
            
            -- Modify cloned request
            cloned_request.method = "POST"
            cloned_request.path = "/modified/path"
            cloned_request.headers["New-Header"] = "new-value"
            cloned_request.query.new_param = "new_value"
            
            -- Original should be unchanged
            assert.equal("GET", test_request.method)
            assert.equal("/test/path", test_request.path)
            assert.is_nil(test_request.headers["New-Header"])
            assert.is_nil(test_request.query.new_param)
        end)
    end)
end)
