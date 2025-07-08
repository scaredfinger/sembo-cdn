local describe = require('busted').describe
local it = require('busted').it
local assert = require('luassert')

local TagsProvider = require "modules.surrogate.providers.tags_provider"

describe("TagsProvider", function()
    it("should not allow direct instantiation", function()
        assert.has_error(function()
            TagsProvider:new()
        end, "TagsProvider is an abstract class and cannot be instantiated directly")
    end)
    
    it("should require implementation of add_key_to_tag", function()
        local instance = setmetatable({}, TagsProvider)
        assert.has_error(function()
            instance:add_key_to_tag("key", "tag")
        end, "add_key_to_tag method must be implemented by concrete tags provider")
    end)
    
    it("should require implementation of remove_key_from_tag", function()
        local instance = setmetatable({}, TagsProvider)
        assert.has_error(function()
            instance:remove_key_from_tag("tag", "key")
        end, "remove_key_from_tag method must be implemented by concrete tags provider")
    end)
    
    it("should require implementation of del_by_tag", function()
        local instance = setmetatable({}, TagsProvider)
        assert.has_error(function()
            instance:del_by_tag("tag")
        end, "del_by_tag method must be implemented by concrete tags provider")
    end)
end)
