require('tests.test_helper')

local describe = require('busted').describe
local it = require('busted').it
local assert = require('luassert')
local spy = require('luassert.spy')
local match = require('luassert.match')

local create_pipeline = require('modules.http.pipelining')

describe("pipelining", function()
    describe("create_pipeline", function()
        it("should execute middlewares in order with final handler", function()
            local execution_order = {}
            
            local middleware1 = {
                execute = function(self, request, next_func)
                    table.insert(execution_order, "middleware1")
                    local modified_request = request .. "-m1"
                    return next_func(modified_request)
                end
            }
            
            local middleware2 = {
                execute = function(self, request, next_func)
                    table.insert(execution_order, "middleware2")
                    local modified_request = request .. "-m2"
                    return next_func(modified_request)
                end
            }
            
            local handler = {
                execute = function(self, request)
                    table.insert(execution_order, "handler")
                    return request .. "-handled"
                end
            }
            
            local pipeline = create_pipeline({middleware1, middleware2}, handler)
            local result = pipeline("request")
            
            assert.are.equal("request-m1-m2-handled", result)
            assert.are.same({"middleware1", "middleware2", "handler"}, execution_order)
        end)
        
        it("should work with no middlewares", function()
            local handler = {
                execute = function(self, request)
                    return request .. "-handled"
                end
            }
            
            local pipeline = create_pipeline({}, handler)
            local result = pipeline("request")
            
            assert.are.equal("request-handled", result)
        end)
        
        it("should work with single middleware", function()
            local middleware = {
                execute = function(self, request, next_func)
                    return next_func(request .. "-modified")
                end
            }
            
            local handler = {
                execute = function(self, request)
                    return request .. "-handled"
                end
            }
            
            local pipeline = create_pipeline({middleware}, handler)
            local result = pipeline("request")
            
            assert.are.equal("request-modified-handled", result)
        end)
        
        it("should allow middleware to short-circuit the pipeline", function()
            local middleware1 = {
                execute = function(self, request, next_func)
                    if request == "short-circuit" then
                        return "short-circuited"
                    end
                    return next_func(request)
                end
            }
            
            local middleware2 = {
                execute = function(self, request, next_func)
                    error("This should not be called")
                end
            }
            
            local handler = {
                execute = function(self, request)
                    error("This should not be called")
                end
            }
            
            local pipeline = create_pipeline({middleware1, middleware2}, handler)
            local result = pipeline("short-circuit")
            
            assert.are.equal("short-circuited", result)
        end)
        
        it("should call all middlewares and handler", function()
            local middleware1 = {
                execute = spy.new(function(self, request, next_func)
                    return next_func(request)
                end)
            }
            
            local middleware2 = {
                execute = spy.new(function(self, request, next_func)
                    return next_func(request)
                end)
            }
            
            local handler = {
                execute = spy.new(function(self, request)
                    return request
                end)
            }
            
            local pipeline = create_pipeline({middleware1, middleware2}, handler)
            pipeline("test")
            
            assert.spy(middleware1.execute).was_called()
            assert.spy(middleware2.execute).was_called()
            assert.spy(handler.execute).was_called()
        end)
    end)
end)
