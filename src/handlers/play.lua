local cjson = require "cjson"
local config = require "modules.config"

local redis_config = config.get_redis_config()

ngx.status = 200
ngx.header["Content-Type"] = "application/json"
ngx.say(cjson.encode({
  redis_config,
  redis_host = os.getenv("REDIS_HOST"),
}))