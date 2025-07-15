local zlib = require "zlib"

local function compress(input)
  local deflate = zlib.deflate()
  local compressed, err = deflate(input, "finish")
  if not compressed then
    return nil, err
  end
  return compressed
end

local function decompress(input)
  local inflate = zlib.inflate()
  local decompressed, err = inflate(input, "finish")
  if not decompressed then
    return nil, err
  end
  return decompressed
end

return {
  encode = compress,
  decode = decompress
}