local describe = require('busted').describe
local before_each = require('busted').before_each
local it = require('busted').it

local assert = require('luassert')
local spy = require('luassert.spy')

local Response = require('modules.http.response')
local Request = require('modules.http.request')
local LogMiddleware = require('modules.logs.middleware')
local event_ids = require('modules.logs.event_ids')

describe("LogMiddleware", function()
    local test_request = Request:new("GET", "/test", {}, "", {}, "localhost")
    local test_response = Response:new(200, "Test response", {})

    local logger
    local sut

    before_each(function()
        logger = {
            debug = spy.new(function() end),
            info = spy.new(function() end),
            warn = spy.new(function() end),
            error = spy.new(function() end),
        }

        sut = LogMiddleware:new(logger)
    end)

    it("logs request start", function()
        local next_handler = spy.new(function() return test_response end)
        
        sut:execute(test_request, next_handler)
        
        assert.spy(logger.debug).was_called_with(logger, {
            event_id = event_ids.LOG_MIDDLEWARE_REQUEST_STARTED_DEBUG,
            request = test_request
        })
    end)

    it("logs successful response", function()
        local next_handler = spy.new(function() return test_response end)
        
        sut:execute(test_request, next_handler)
        
        assert.spy(logger.debug).was_called_with(logger, {
            event_id = event_ids.LOG_MIDDLEWARE_REQUEST_FINISHED_DEBUG,
            request = test_request,
            response = test_response
        })
    end)

    it("calls next handler and returns response", function()
        local next_handler = spy.new(function() return test_response end)
        
        local result = sut:execute(test_request, next_handler)
        
        assert.spy(next_handler).was_called_with(test_request)
        assert.equal(test_response, result)
    end)

    it("logs error when next handler fails", function()
        local error_message = "Handler failed"
        local next_handler = spy.new(function() error(error_message) end)
        
        local success, result = pcall(function()
            sut:execute(test_request, next_handler)
        end)
        
        assert.is_false(success)
        assert.spy(logger.error).was_called()
        local error_call = logger.error.calls[1]
        assert.equal(event_ids.LOG_MIDDLEWARE_REQUEST_ERROR, error_call.vals[2].event_id)
        assert.equal(test_request.path, error_call.vals[2].request.path)
        assert.is_string(error_call.vals[2].error)
    end)

    it("re-raises error after logging", function()
        local error_message = "Handler failed"
        local next_handler = spy.new(function() error(error_message) end)
        
        local success, result = pcall(function()
            sut:execute(test_request, next_handler)
        end)
        
        assert.is_false(success)
        assert.matches(error_message, result)
    end)

    it("does not log finished when next handler fails", function()
        local next_handler = spy.new(function() error("Handler failed") end)
        
        pcall(function()
            sut:execute(test_request, next_handler)
        end)
        
        local finished_calls = 0
        for _, call in ipairs(logger.debug.calls) do
            if call.vals[2] and call.vals[2].event_id == event_ids.LOG_MIDDLEWARE_REQUEST_FINISHED_DEBUG then
                finished_calls = finished_calls + 1
            end
        end
        assert.equal(0, finished_calls)
    end)
end)
