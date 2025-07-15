local zlib = require "ffi-zlib"
local function compress(input)
  local pos = 1
  local output = {}
  
  local function in_fn(n)
    if pos > #input then return nil end
    local chunk = input:sub(pos, pos + n - 1)
    pos = pos + n
    return chunk
  end
  
  local function out_fn(chunk)
    output[#output + 1] = chunk
  end
  
  local ok, err = zlib.deflateGzip(in_fn, out_fn)
  if not ok then
    return nil, err
  end
  
  return table.concat(output)
end

local function decompress(input)
  local pos = 1
  local output = {}
  
  local function in_fn(n)
    if pos > #input then return nil end
    local chunk = input:sub(pos, pos + n - 1)
    pos = pos + n
    return chunk
  end
  
  local function out_fn(chunk)
    output[#output + 1] = chunk
  end
  
  local ok, err = zlib.inflateGzip(in_fn, out_fn)
  if not ok then
    return nil, err
  end
  
  return table.concat(output)
end

return {
  encode = compress,
  decode = decompress
}