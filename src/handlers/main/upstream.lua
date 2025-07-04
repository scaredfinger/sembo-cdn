local Upstream = require "modules.http.upstream"
local config = require "modules.config"

--- @type Upstream
local upstream = Upstream:new(config.get_backend_url())

--- @return function
local function create_upstream_function()
    return function(req)
        return upstream:execute(req)
    end
end

local execute_upstream = create_upstream_function()
return execute_upstream