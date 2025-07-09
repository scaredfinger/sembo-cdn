local RedisTagsProvider = require "modules.surrogate.providers.redis_tags_provider"

local config = require "modules.config"

local redis_config = config.get_redis_config()

local function open_connection()
  local redis = require("resty.redis")
  local redis_connection = redis:new()
  redis_connection:set_timeout(config.timeout)
  redis_connection:connect(
    redis_config.host,
    redis_config.port or 6379
  )
  return redis_connection
end

local function close_connection(connection)
  if ngx.get_phase() == "timer" then
    connection:close()
  else
    connection:set_keepalive(10000, 100)
  end
  return true
end

local redis_provider = RedisTagsProvider:new(open_connection, close_connection)
return redis_provider