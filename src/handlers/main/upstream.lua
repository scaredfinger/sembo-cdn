local Upstream = require "modules.http.upstream"
local config = require "utils.config"

--- @type Upstream
local upstream = Upstream:new(config.get_backend_url())
return upstream