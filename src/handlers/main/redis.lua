---@param client table|nil
---@return table|nil
local function test_existing_connection(client)
    if not client then
        return nil
    end

    local connection_is_healthy, ping_error = client:ping()
    if connection_is_healthy then
        return client
    else
        ngx.log(ngx.WARN, "Redis connection unhealthy, reconnecting: ", ping_error)
        return nil
    end
end

---@param config table
---@return table|nil
local function create_new_redis_connection(config)
    local redis = require("resty.redis")
    local new_client = redis:new()
    new_client:set_timeout(config.timeout)

    local connection_established, connection_error = new_client:connect(config.host, config.port)
    if not connection_established then
        ngx.log(ngx.ERR, "Failed to connect to Redis: ", connection_error)
        return nil
    end

    return new_client
end

---@param client table
---@param config table
---@return boolean
local function authenticate_redis_client(client, config)
    if not config.password then
        return true
    end

    local auth_success, auth_error = client:auth(config.password)
    if not auth_success then
        ngx.log(ngx.ERR, "Failed to authenticate with Redis: ", auth_error)
        return false
    end

    return true
end

---@param client table
---@param config table
---@return boolean
local function select_redis_database(client, config)
    if not config.database or config.database <= 0 then
        return true
    end

    local select_success, select_error = client:select(config.database)
    if not select_success then
        ngx.log(ngx.ERR, "Failed to select Redis database: ", select_error)
        return false
    end

    return true
end

---@param current_client table|nil
---@param config table
---@return table|nil
local function get_or_create_redis_client(current_client, config)
    local existing_connection = test_existing_connection(current_client)
    if existing_connection then
        return existing_connection
    end

    local new_connection = create_new_redis_connection(config)
    if not new_connection then
        return nil
    end

    local auth_successful = authenticate_redis_client(new_connection, config)
    if not auth_successful then
        return nil
    end

    local database_selected = select_redis_database(new_connection, config)
    if not database_selected then
        return nil
    end

    return new_connection
end

return get_or_create_redis_client
