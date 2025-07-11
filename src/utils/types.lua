--- @alias LogLevel "debug" | "info" | "warn" | "error"
--- @alias LogLevelValue 1 | 2 | 3 | 4

local log_levels = {
    debug = 1,
    info = 2,
    warn = 3,
    error = 4
}

return {
    log_levels = log_levels
}