local Handler = require('modules.http.handler')
local Response = require('modules.http.response')

--- @class InvalidateTagHandler : Handler
--- @field tags_provider TagsProvider
--- @field cache_provider CacheProvider
--- @field __index InvalidateTagHandler
local InvalidateTagHandler = {}
InvalidateTagHandler.__index = InvalidateTagHandler
setmetatable(InvalidateTagHandler, {__index = Handler})

--- @param tags_provider TagsProvider
--- @param cache_provider CacheProvider
--- @return InvalidateTagHandler
function InvalidateTagHandler:new(tags_provider, cache_provider)
    local instance = setmetatable({}, InvalidateTagHandler)
    instance.tags_provider = tags_provider
    instance.cache_provider = cache_provider
    return instance
end

--- @param request Request
--- @return Response
function InvalidateTagHandler:execute(request)
    -- Only handle DELETE requests
    if request.method ~= "DELETE" then
        return Response:new(405, "Method Not Allowed", {
            ["Allow"] = "DELETE"
        })
    end

    -- Extract tag from path: /cache/tags/{tag_name}
    local tag = self:_extract_tag_from_path(request.path)
    if not tag then
        return Response:new(400, "Bad Request: Invalid tag format", {
            ["Content-Type"] = "text/plain"
        })
    end

    -- Validate tag format (simple validation for now)
    if tag == "" or string.match(tag, "%s") then
        return Response:new(400, "Bad Request: Invalid tag format", {
            ["Content-Type"] = "text/plain"
        })
    end

    -- Perform invalidation
    -- Step 1: Get all cache keys for this tag
    local cache_keys = self.tags_provider:get_keys_for_tag(tag)
    if not cache_keys then
        return Response:new(500, "Internal Server Error: Failed to retrieve cache keys for tag", {
            ["Content-Type"] = "text/plain"
        })
    end

    -- Step 2: Delete all cache entries
    for _, cache_key in ipairs(cache_keys) do
        local cache_delete_success = self.cache_provider:del(cache_key)
        if not cache_delete_success then
            -- Log error but continue with other keys
            -- In a real implementation, you might want to collect failed keys
        end
    end

    -- Step 3: Delete the tag mappings
    local tag_delete_success = self.tags_provider:del_by_tag(tag)
    if not tag_delete_success then
        return Response:new(500, "Internal Server Error: Failed to delete tag mappings", {
            ["Content-Type"] = "text/plain"
        })
    end

    -- Return success response with count of invalidated keys
    local response_body = string.format("Invalidated %d cache entries for tag '%s'", #cache_keys, tag)
    return Response:new(200, response_body, {
        ["Content-Type"] = "text/plain",
        ["Cache-Control"] = "no-cache"
    })
end

--- Extract tag name from request path
--- @param path string
--- @return string|nil
function InvalidateTagHandler:_extract_tag_from_path(path)
    -- Match /cache/tags/{tag_name} pattern
    local tag = string.match(path, "^/cache/tags/([^/]+)$")
    return tag
end

return InvalidateTagHandler
