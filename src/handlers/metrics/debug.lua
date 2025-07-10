-- Create metrics instance
local metrics = require "handlers.metrics.instance"

local prometheus_output = metrics:generate_prometheus()
-- Set content type for Prometheus
ngx.header["Content-Type"] = "text/plain; version=0.0.4; charset=utf-8"

--- @type SharedDictionary
local shared_metrics = ngx.shared.metrics
local keys = shared_metrics:get_keys(0)
local capacity = shared_metrics:capacity()
local free_space = shared_metrics:free_space()

ngx.print("# Stats")
ngx.print("\n")
ngx.print('keys: ' .. #keys .. "\n")
ngx.print('capacity: ' .. (capacity / 1024) .. "kb\n")
ngx.print('free_space: ' .. (free_space / 1024) .. "kb\n")

local output = {}
for _, key in ipairs(keys) do
  local value = shared_metrics:get(key)
  if value then
    local line = string.format("%s: %s", key, value)
    if line then
      table.insert(output, line)
    end
  end
end

ngx.print(table.concat(output, "\n") .. "\n")
