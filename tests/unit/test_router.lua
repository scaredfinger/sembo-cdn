local describe = require('busted').describe
local it = require('busted').it

local assert = require('luassert')

-- Unit tests for router module
require "tests.test_helper"  -- Load ngx mocks before requiring modules

describe("router module", function()
    local router = require "modules.router"
    
    describe("get_pattern", function()
        it("should match hotel name pattern", function()
            local pattern = router.get_pattern("/hotels/luxury-resort")
            assert.equals("hotels/[name]", pattern)
        end)
        
        it("should match hotel rooms pattern", function()
            local pattern = router.get_pattern("/hotels/beach-hotel/rooms")
            assert.equals("hotels/[name]/rooms", pattern)
        end)
        
        it("should match specific room pattern", function()
            local pattern = router.get_pattern("/hotels/city-inn/rooms/101")
            assert.equals("hotels/[name]/rooms/[id]", pattern)
        end)
        
        it("should match API version pattern", function()
            local pattern = router.get_pattern("/api/v1/users")
            assert.equals("api/v[version]", pattern)
        end)
        
        it("should match user ID pattern", function()
            local pattern = router.get_pattern("/users/12345")
            assert.equals("users/[id]", pattern)
        end)
        
        it("should match search pattern", function()
            local pattern = router.get_pattern("/search?q=test")
            assert.equals("search", pattern)
        end)
        
        it("should return truncated URI for unmatched patterns", function()
            local pattern = router.get_pattern("/some/very/long/unmatched/path")
            assert.is_not.equals("unknown", pattern)
            assert.is_string(pattern)
        end)
        
        it("should handle nil URI", function()
            local pattern = router.get_pattern(nil)
            assert.equals("default", pattern)
        end)
        
        it("should handle empty URI", function()
            local pattern = router.get_pattern("")
            assert.is_string(pattern)
        end)
    end)
    
    describe("add_pattern", function()
        it("should add new pattern", function()
            router.add_pattern("^/test/([^/]+)$", "test/[id]")
            local pattern = router.get_pattern("/test/123")
            assert.equals("test/[id]", pattern)
        end)
    end)
    
    describe("get_all_patterns", function()
        it("should return array of patterns", function()
            local patterns = router.get_all_patterns()
            assert.is_table(patterns)
            assert.is_true(#patterns > 0)
        end)
    end)
end)
