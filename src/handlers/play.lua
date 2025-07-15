local zlib = require "ffi-zlib"


ngx.say(zlib ~= nil and "ffi-zlib loaded successfully" or "Failed to load ffi-zlib")
ngx.say("Gzip: ", gzip ~= nil and "available" or "not available")
