local InvalidateTagHandler = require "modules.surrogate.invalidate_tag_handler"

local tags_provider = require "handlers.utils.tags_provider"
local cache_provider = require "handlers.utils.cache_provider"

local handler = InvalidateTagHandler:new(tags_provider, cache_provider)
return handler
