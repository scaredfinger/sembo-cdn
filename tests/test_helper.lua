-- Test helper to mock ngx environment
-- This file should be required before any modules that use ngx

-- Mock ngx object if not available
if not ngx then
    ngx = {}
end

-- Mock ngx.shared with metrics dictionary
if not ngx.shared then
    ngx.shared = {
        metrics = {
            _data = {},
            set = function(self, key, value)
                self._data[key] = value
                return true
            end,
            get = function(self, key)
                return self._data[key]
            end,
            incr = function(self, key, value)
                value = value or 1
                local current = self._data[key] or 0
                self._data[key] = current + value
                return self._data[key]
            end,
            get_keys = function(self)
                local keys = {}
                for k, v in pairs(self._data) do
                    table.insert(keys, k)
                end
                return keys
            end,
            add = function(self, key, value)
                if self._data[key] then
                    return false, "exists"
                end
                self._data[key] = value
                return true
            end
        }
    }
end

-- Mock ngx log levels and functions
ngx.DEBUG = 7
ngx.INFO = 6
ngx.WARN = 4
ngx.ERR = 3
ngx.CRIT = 2

-- Mock logging function (prints to stdout in tests)
ngx.log = function(level, ...)
    local args = {...}
    local message = table.concat(args, " ")
    print("[TEST LOG] " .. message)
end

-- Mock ngx.var
if not ngx.var then
    ngx.var = {
        request_uri = "/test",
        http_host = "test.example.com",
        remote_addr = "127.0.0.1",
        request_method = "GET",
        args = "",
        uri = "/test"
    }
end

-- Mock ngx.req
if not ngx.req then
    ngx.req = {
        get_headers = function()
            return {
                ["user-agent"] = "test-agent",
                ["host"] = "test.example.com"
            }
        end,
        get_method = function()
            return "GET"
        end,
        get_uri_args = function()
            return {}
        end
    }
end

-- Helper function to reset mocks between tests
function reset_ngx_mocks()
    if ngx.shared and ngx.shared.metrics and ngx.shared.metrics._data then
        ngx.shared.metrics._data = {}
    end
end
