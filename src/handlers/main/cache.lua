local RedisCacheProvider = require("modules.cache.providers.redis_cache_provider")
local CacheMiddleware = require("modules.cache.cache_middleware")
local cache_key_strategy_host_path = require("modules.cache.cache_key_strategy_host_path")
local cache_control_parser = require("modules.cache.cache_control_parser")

local config = require("modules.config")

local redis_config = config.get_redis_config()

---@type table
local redis_client
local cache_instance

---@return table|nil
local function test_existing_connection()
    if not redis_client then
        return nil
    end

    local connection_is_healthy, ping_error = redis_client:ping()
    if connection_is_healthy then
        return redis_client
    else
        ngx.log(ngx.WARN, "Redis connection unhealthy, reconnecting: ", ping_error)
        return nil
    end
end

---@return table|nil
local function create_new_redis_connection()
    local redis = require("resty.redis")
    local new_client = redis:new()
    new_client:set_timeout(redis_config.timeout)

    local connection_established, connection_error = new_client:connect(redis_config.host, redis_config.port)
    if not connection_established then
        ngx.log(ngx.ERR, "Failed to connect to Redis: ", connection_error)
        return nil
    end

    return new_client
end

---@param client table
---@return boolean
local function authenticate_redis_client(client)
    if not redis_config.password then
        return true
    end

    local auth_success, auth_error = client:auth(redis_config.password)
    if not auth_success then
        ngx.log(ngx.ERR, "Failed to authenticate with Redis: ", auth_error)
        return false
    end

    return true
end

---@param client table
---@return boolean
local function select_redis_database(client)
    if not redis_config.database or redis_config.database <= 0 then
        return true
    end

    local select_success, select_error = client:select(redis_config.database)
    if not select_success then
        ngx.log(ngx.ERR, "Failed to select Redis database: ", select_error)
        return false
    end

    return true
end

---@return table|nil
local function get_or_create_redis_client()
    local existing_connection = test_existing_connection()
    if existing_connection then
        return existing_connection
    end

    local new_connection = create_new_redis_connection()
    if not new_connection then
        return nil
    end

    local auth_successful = authenticate_redis_client(new_connection)
    if not auth_successful then
        return nil
    end

    local database_selected = select_redis_database(new_connection)
    if not database_selected then
        return nil
    end

    redis_client = new_connection
    return redis_client
end

---@return function
local function create_defer_function()
    return function(fn)
        ngx.timer.at(0, fn)
    end
end

---@return table
local function init_cache()
    if cache_instance then
        return cache_instance
    end

    local redis_connection = get_or_create_redis_client()
    if not redis_connection then
        ngx.log(ngx.ERR, "Cannot initialize cache without Redis connection")
        error("Failed to initialize Redis client")
    end

    local redis_provider = RedisCacheProvider:new(redis_connection)
    local defer_function = create_defer_function()

    cache_instance = CacheMiddleware:new(redis_provider, cache_key_strategy_host_path, cache_control_parser,
    defer_function)
    return cache_instance
end

local cache_proxy = {
    execute = function(self, request, upstream_fn)
        local initialized_cache = init_cache()
        return initialized_cache:execute(request, upstream_fn)
    end
}

return cache_proxy
