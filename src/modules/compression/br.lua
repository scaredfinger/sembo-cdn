local BrotliEncoder = require "resty.brotli.encoder"
local brotliEncoder = BrotliEncoder:new({
  quality = 4,
  mode = 1,
})

local BrotliDecoder = require "resty.brotli.decoder"
local brotliDecoder = BrotliDecoder:new()

return {
  encode = function(data)
    return brotliEncoder:compress(data)
  end,

  decode = function(data)
    return brotliDecoder:decompress(data)
  end
}
