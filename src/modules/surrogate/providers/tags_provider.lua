--- @class TagsProvider
--- @field __index TagsProvider
local TagsProvider = {}
TagsProvider.__index = TagsProvider

--- @return TagsProvider
function TagsProvider:new()
    error("TagsProvider is an abstract class and cannot be instantiated directly")
end

--- @param key string
--- @param tag string 
--- @return boolean
function TagsProvider:add_key_to_tag(key, tag)
    error("add_key_to_tag method must be implemented by concrete tags provider")
end

--- @param key string
--- @param tag string
--- @return boolean
function TagsProvider:remove_key_from_tag(tag, key)
    error("remove_key_from_tag method must be implemented by concrete tags provider")
end

--- @param tag string 
--- @return boolean 
function TagsProvider:del_by_tag(tag)
    error("del_by_tag method must be implemented by concrete tags provider")
end

return TagsProvider
