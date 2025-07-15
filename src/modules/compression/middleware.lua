--- @alias Decompressor fun(data: string): string
--- @alias CodecFun fun(data: string): string

--- @alias Codec { encode: CodecFun, decode: CodecFun }

--- @class CompressionMiddleware: Middleware
--- @field gzip Codec
--- @field brotli Codec
--- @field deflate Codec
--- @field __index CompressionMiddleware
local CompressionMiddleware = {}
CompressionMiddleware.__index = CompressionMiddleware

--- @param gzip Codec
--- @param brotli Codec
--- @param deflate Codec
--- @return CompressionMiddleware
function CompressionMiddleware:new(gzip, brotli, deflate)
    local instance = setmetatable({}, CompressionMiddleware)
    instance.gzip = gzip
    instance.brotli = brotli
    instance.deflate = deflate
    return instance
end

--- @private
--- @param accept_encoding string
--- @return string|nil
function CompressionMiddleware:_get_preferred_encoding(accept_encoding)
    if not accept_encoding then
        return nil
    end

    local supported_encodings = {}
    for encoding in accept_encoding:gmatch("([^,]+)") do
        local name = encoding:match("^([^;]+)")
        if name then
            name = name:lower():gsub("^%s*", ""):gsub("%s*$", "")
            if name == "br" or name == "gzip" or name == "deflate" then
                supported_encodings[name] = true
            end
        end
    end

    if supported_encodings["br"] then
        return "br"
    elseif supported_encodings["gzip"] then
        return "gzip"
    elseif supported_encodings["deflate"] then
        return "deflate"
    end

    return nil
end

--- @private
--- @param accept_encoding string
--- @param current_encoding string|nil
--- @return string|nil
function CompressionMiddleware:_get_preferred_encoding_with_upstream_priority(accept_encoding, current_encoding)
    if not accept_encoding then
        return nil
    end

    local supported_encodings = {}
    for encoding in accept_encoding:gmatch("([^,]+)") do
        local name = encoding:match("^([^;]+)")
        if name then
            name = name:lower():gsub("^%s*", ""):gsub("%s*$", "")
            if name == "br" or name == "gzip" or name == "deflate" then
                supported_encodings[name] = true
            end
        end
    end

    if current_encoding == "deflate" and supported_encodings["deflate"] then
        return "deflate"
    end

    if supported_encodings["br"] then
        return "br"
    elseif supported_encodings["gzip"] then
        return "gzip"
    elseif supported_encodings["deflate"] then
        return "deflate"
    end

    return nil
end

--- @private
--- @param content_encoding string|nil
--- @return string|nil
function CompressionMiddleware:_get_current_encoding(content_encoding)
    if not content_encoding then
        return nil
    end
    
    local encoding = content_encoding:lower():gsub("^%s*", ""):gsub("%s*$", "")
    if encoding == "br" or encoding == "gzip" or encoding == "deflate" then
        return encoding
    end
    
    return nil
end

--- @private
--- @param encoding string
--- @param accept_encoding string|nil
--- @return boolean
function CompressionMiddleware:_is_encoding_acceptable(encoding, accept_encoding)
    if not accept_encoding then
        return false
    end

    local supported_encodings = {}
    for accepted_encoding in accept_encoding:gmatch("([^,]+)") do
        local name = accepted_encoding:match("^([^;]+)")
        if name then
            name = name:lower():gsub("^%s*", ""):gsub("%s*$", "")
            if name == "br" or name == "gzip" or name == "deflate" then
                supported_encodings[name] = true
            end
        end
    end

    return supported_encodings[encoding] == true
end

--- @private
--- @param body string
--- @param current_encoding string|nil
--- @return string
function CompressionMiddleware:_decompress_body(body, current_encoding)
    if current_encoding == "gzip" then
        return self.gzip.decode(body)
    elseif current_encoding == "br" then
        return self.brotli.decode(body)
    elseif current_encoding == "deflate" then
        return self.deflate.decode(body)
    end
    return body
end

--- @private
--- @param body string
--- @param preferred_encoding string|nil
--- @return string, string|nil
function CompressionMiddleware:_compress_body(body, preferred_encoding)
    if preferred_encoding == "gzip" then
        return self.gzip.encode(body), "gzip"
    elseif preferred_encoding == "br" then
        return self.brotli.encode(body), "br"
    elseif preferred_encoding == "deflate" then
        return self.deflate.encode(body), "deflate"
    end
    return body, nil
end

--- @private
--- @param content_type string|nil
--- @return boolean
function CompressionMiddleware:_is_compressible_content(content_type)
    if not content_type then
        return false
    end
    
    return content_type:match("text/") or
           content_type:match("application/json") or
           content_type:match("application/javascript") or
           content_type:match("application/xml")
end

--- @param request Request
--- @param next fun(request: Request): Response
function CompressionMiddleware:execute(request, next)
    local response = next(request)
    
    if not response.body or #response.body == 0 then
        return response
    end

    local content_type = response.headers["Content-Type"]
    if not self:_is_compressible_content(content_type) then
        return response
    end

    local accept_encoding = request.headers["Accept-Encoding"]
    local current_encoding = self:_get_current_encoding(response.headers["Content-Encoding"])
    local preferred_encoding = self:_get_preferred_encoding_with_upstream_priority(accept_encoding, current_encoding)

    if current_encoding and self:_is_encoding_acceptable(current_encoding, accept_encoding) then
        return response
    end

    if preferred_encoding == current_encoding then
        return response
    end

    local decompressed_body = self:_decompress_body(response.body, current_encoding)
    local final_body, final_encoding = self:_compress_body(decompressed_body, preferred_encoding)

    local modified_response = response:clone()
    modified_response.body = final_body
    
    if final_encoding then
        modified_response.headers["Content-Encoding"] = final_encoding
    else
        modified_response.headers["Content-Encoding"] = nil
    end
    
    modified_response.headers["Content-Length"] = tostring(#final_body)
    modified_response.headers["Transfer-Encoding"] = nil
    modified_response.headers["Vary"] = "Accept-Encoding"

    modified_response.locals.compression_encoding = final_encoding
    modified_response.locals.compression_original_encoding = current_encoding
    modified_response.locals.compression_ratio = #decompressed_body > 0 and (#final_body / #decompressed_body) or 1

    return modified_response
end

return CompressionMiddleware
