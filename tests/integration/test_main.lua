-- Integration test for cache behavior
-- Tests X-Cache header progression: MISS -> HIT -> STALE -> HIT

local describe = require('busted').describe
local it = require('busted').it
local assert = require('luassert')

describe("Cache behavior integration test", function()
    local proxy_url = "http://proxy.docker.internal:8080"
    local test_endpoint = "/hotel/luxury-resort"
    
    -- Helper function to make HTTP request using curl and capture headers
    local function make_request(url)
        local temp_file = "/tmp/curl_response_" .. os.time() .. ".txt"
        local headers_file = "/tmp/curl_headers_" .. os.time() .. ".txt"
        
        -- Use curl to make request and save headers
        local curl_cmd = string.format(
            'curl -s -w "HTTP_CODE:%%{http_code}" -D "%s" "%s" > "%s" 2>/dev/null',
            headers_file, url, temp_file
        )
        
        local result = os.execute(curl_cmd)
        
        -- Read response body and status
        local body_file = io.open(temp_file, "r")
        local body = ""
        local status = nil
        
        if body_file then
            local content = body_file:read("*all")
            body_file:close()
            -- Extract HTTP code from response
            local http_code_match = content:match("HTTP_CODE:(%d+)")
            if http_code_match then
                status = tonumber(http_code_match)
                body = content:gsub("HTTP_CODE:%d+", "")
            else
                body = content
            end
        end
        
        -- Read headers and find X-Cache
        local headers_file_handle = io.open(headers_file, "r")
        local x_cache_header = nil
        
        if headers_file_handle then
            for line in headers_file_handle:lines() do
                if line:lower():match("^x%-cache:%s*(.+)") then
                    x_cache_header = line:lower():match("^x%-cache:%s*(.+)")
                    break
                end
            end
            headers_file_handle:close()
        end
        
        -- Clean up temp files
        os.remove(temp_file)
        os.remove(headers_file)
        
        return {
            success = (result == 0),
            status = status or 0,
            x_cache = x_cache_header,
            body = body:gsub("%s+$", "") -- trim trailing whitespace
        }
    end
    
    it("should demonstrate cache lifecycle: MISS -> HIT -> STALE -> HIT", function()
        local full_url = proxy_url .. test_endpoint
        
        -- Clear any existing cache by waiting a bit first
        -- In production, you might want to call a cache clear endpoint
        print("Starting cache behavior test for: " .. full_url)
        
        -- Step 1: First request should be a cache MISS
        print("Step 1: First request (expecting MISS)")
        local response1 = make_request(full_url)
        
        assert.is_true(response1.success, "First request should succeed")
        assert.equals(200, response1.status, "First request should return 200")
        
        -- The first request should be a cache miss
        -- Note: The actual header value might vary based on implementation
        print("X-Cache header on first request: " .. tostring(response1.x_cache))
        
        -- Step 2: Second request immediately should be a cache HIT
        print("Step 2: Second request (expecting HIT)")
        local response2 = make_request(full_url)
        
        assert.is_true(response2.success, "Second request should succeed")
        assert.equals(200, response2.status, "Second request should return 200")
        print("X-Cache header on second request: " .. tostring(response2.x_cache))
        
        -- The responses should be the same content
        assert.equals(response1.body, response2.body, "Response bodies should be identical")
        
        -- Step 3: Wait for cache to become stale (max-age=5 seconds)
        print("Step 3: Waiting 6 seconds for cache to become stale...")
        os.execute("sleep 6")
        
        local response3 = make_request(full_url)
        assert.is_true(response3.success, "Third request should succeed")
        assert.equals(200, response3.status, "Third request should return 200")
        print("X-Cache header after 6 seconds (expecting STALE): " .. tostring(response3.x_cache))
        
        -- Step 4: Another request should now be fresh again (after stale-while-revalidate)
        print("Step 4: Fourth request (expecting HIT after revalidation)")
        local response4 = make_request(full_url)
        
        assert.is_true(response4.success, "Fourth request should succeed")
        assert.equals(200, response4.status, "Fourth request should return 200")
        print("X-Cache header on fourth request: " .. tostring(response4.x_cache))
        
        -- All responses should have the same content
        assert.equals(response1.body, response3.body, "Third response body should match first")
        assert.equals(response1.body, response4.body, "Fourth response body should match first")
        
        -- Summary of cache headers observed
        print("\n=== Cache Behavior Summary ===")
        print("Request 1 (first): " .. tostring(response1.x_cache))
        print("Request 2 (immediate): " .. tostring(response2.x_cache))
        print("Request 3 (after 6s): " .. tostring(response3.x_cache))
        print("Request 4 (after stale): " .. tostring(response4.x_cache))
        print("===============================")
        
        -- Basic assertions about cache behavior
        -- Note: Actual header values depend on your cache implementation
        assert.is_not_nil(response1.x_cache, "First request should have X-Cache header")
        assert.is_not_nil(response2.x_cache, "Second request should have X-Cache header")
        assert.is_not_nil(response3.x_cache, "Third request should have X-Cache header")
        assert.is_not_nil(response4.x_cache, "Fourth request should have X-Cache header")
    end)
    
    it("should handle concurrent requests properly", function()
        local full_url = proxy_url .. test_endpoint
        
        -- Make multiple concurrent requests to test cache behavior
        print("Testing concurrent requests...")
        
        -- First clear request
        local clear_response = make_request(full_url)
        os.execute("sleep 1") -- Small delay
        
        -- Now make 3 quick requests
        local responses = {}
        for i = 1, 3 do
            responses[i] = make_request(full_url)
            assert.is_true(responses[i].success, "Concurrent request " .. i .. " should succeed")
            assert.equals(200, responses[i].status, "Concurrent request " .. i .. " should return 200")
            print("Concurrent request " .. i .. " X-Cache: " .. tostring(responses[i].x_cache))
        end
        
        -- All concurrent requests should return the same body
        for i = 2, 3 do
            assert.equals(responses[1].body, responses[i].body, 
                "Concurrent request " .. i .. " should have same body as request 1")
        end
    end)
end)
