local zlib = require "zlib"

local function compress(input)
  local gzip = zlib.deflate(nil, 31)
  local compressed, err = gzip(input, "finish")
  if not compressed then
    return nil, err
  end
  return compressed
end

local function decompress(input)
  local gunzip = zlib.inflate(nil, 31)
  local decompressed, err = gunzip(input, "finish")
  if not decompressed then
    return nil, err
  end
  return decompressed
end

return {
  encode = compress,
  decode = decompress
}