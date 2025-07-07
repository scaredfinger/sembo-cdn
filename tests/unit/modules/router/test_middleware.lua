local describe = require('busted').describe
local before_each = require('busted').before_each
local it = require('busted').it

local assert = require('luassert')
local spy = require('luassert.spy')
local stub = require('luassert.stub')

local Response = require('modules.http.response')
local Request = require('modules.http.request')
local router = require('modules.router')

local RouterMiddleware = require('modules.router.middleware')

describe("RouterMiddleware", function()
    local routes_config = {
        patterns = {
            { name = "api_search", regex = "^/api/search" }
        },
        fallback = "unknown"
    }

    local test_request = Request:new("GET", "/test/path", {}, "", {}, "localhost")
    local test_response = Response:new(200, "Test response", {})

    --- @type fun(request: Request): Response
    local function next(request)
        return test_response
    end

    --- @type RouterMiddleware
    local sut

    before_each(function()
        sut = RouterMiddleware:new(routes_config)
        test_response.locals = {}
    end)

    it("can be instantiated", function()
        assert.is_not_nil(sut)
        assert.is_true(getmetatable(sut) == RouterMiddleware)
    end)

    it("stores routes_config on instantiation", function()
        assert.equal(routes_config, sut.routes_config)
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

        it("calls router.get_pattern_from_routes with correct parameters", function()
            local router_spy = spy.on(router, "get_pattern_from_routes")

            sut:execute(test_request, next)

            assert.spy(router_spy).was_called(1)
            assert.spy(router_spy).was_called_with(routes_config, test_request.path)
            
            router_spy:revert()
        end)

        it("adds route to response locals", function()
            local router_stub = stub(router, "get_pattern_from_routes").returns("test_route")

            local response = sut:execute(test_request, next)

            assert.equal("test_route", response.locals.route)
            
            router_stub:revert()
        end)

        describe("when response already has locals", function()
            it("preserves existing locals", function()
                test_response.locals = { existing_key = "existing_value" }
                local router_stub = stub(router, "get_pattern_from_routes").returns("test_route")
                
                local response = sut:execute(test_request, next)

                assert.equal("existing_value", response.locals.existing_key)
                assert.equal("test_route", response.locals.route)
                
                router_stub:revert()
            end)
        end)
    end)
end)