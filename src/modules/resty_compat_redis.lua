local redis = require("redis")

local RestyCompatRedis = {}
RestyCompatRedis.__index = RestyCompatRedis

function RestyCompatRedis:new()
  local instance = setmetatable({}, RestyCompatRedis)
  return instance
end

function RestyCompatRedis:connect(host, port)
  self.client = redis.connect(host or "127.0.0.1", port or 6379)
  return true
end

function RestyCompatRedis:set(key, value)
  return self.client:set(key, value)
end

function RestyCompatRedis:get(key)
  return self.client:get(key)
end

function RestyCompatRedis:sadd(key, ...)
  return self.client:sadd(key, ...)
end

function RestyCompatRedis:smembers(key)
  return self.client:smembers(key)
end

function RestyCompatRedis:srem(key, ...)
  return self.client:srem(key, ...)
end

function RestyCompatRedis:del(...)
  return self.client:del(...)
end


return RestyCompatRedis
