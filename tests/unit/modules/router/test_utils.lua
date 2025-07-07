local describe = require('busted').describe
local before_each = require('busted').before_each
local it = require('busted').it
local assert = require('luassert')
local router_utils = require("modules.router.utils")

describe("Router Utils", function()
    local temp_file_path = "/tmp/test_patterns.json"
    local valid_config = {
        patterns = {
            {
                regex = "^/hotels/([^/]+)$",
                name = "hotels/[name]"
            },
            {
                regex = "^/hotels/([^/]+)/rooms$",
                name = "hotels/[name]/rooms"
            },
            {
                regex = "^/api/v(%d+)/",
                name = "api/v[version]"
            },
            {
                regex = "^/search\\?",
                name = "search"
            }
        },
        fallback = "unknown"
    }

    local function create_temp_file(content)
        local file = io.open(temp_file_path, "w")
        if file then
            file:write(content)
            file:close()
        end
    end

    local function cleanup_temp_file()
        os.remove(temp_file_path)
    end

    describe("load_patterns_from_file", function()
        describe("happy paths", function()
            it("should load valid patterns from file", function()
                local json_content = [[{
                    "patterns": [
                        {
                            "regex": "^/hotels/([^/]+)$",
                            "name": "hotels/[name]"
                        },
                        {
                            "regex": "^/api/v(\\d+)/",
                            "name": "api/v[version]"
                        }
                    ],
                    "fallback": "unknown"
                }]]
                
                create_temp_file(json_content)
                
                local result = router_utils.load_patterns_from_file(temp_file_path)
                
                assert.are.equal(2, #result.patterns)
                assert.are.equal("^/hotels/([^/]+)$", result.patterns[1].regex)
                assert.are.equal("hotels/[name]", result.patterns[1].name)
                assert.are.equal("^/api/v(\\d+)/", result.patterns[2].regex)
                assert.are.equal("api/v[version]", result.patterns[2].name)
                assert.are.equal("unknown", result.fallback)
                
                cleanup_temp_file()
            end)

            it("should use default fallback when not specified", function()
                local json_content = [[{
                    "patterns": [
                        {
                            "regex": "^/test$",
                            "name": "test"
                        }
                    ]
                }]]
                
                create_temp_file(json_content)
                
                local result = router_utils.load_patterns_from_file(temp_file_path)
                
                assert.are.equal("unknown", result.fallback)
                
                cleanup_temp_file()
            end)
        end)

        describe("error cases", function()
            it("should error when no file path provided", function()
                assert.has_error(function()
                    router_utils.load_patterns_from_file(nil)
                end, "No file path provided for route patterns")
            end)

            it("should error when file does not exist", function()
                assert.has_error(function()
                    router_utils.load_patterns_from_file("/nonexistent/file.json")
                end, "Could not open route patterns config file: /nonexistent/file.json")
            end)

            it("should error when file contains invalid JSON", function()
                create_temp_file("invalid json {")
                
                assert.has_error(function()
                    router_utils.load_patterns_from_file(temp_file_path)
                end)
                
                cleanup_temp_file()
            end)

            it("should error when patterns array is missing", function()
                create_temp_file('{"fallback": "unknown"}')
                
                assert.has_error(function()
                    router_utils.load_patterns_from_file(temp_file_path)
                end, "Invalid route patterns config: missing or invalid 'patterns' array")
                
                cleanup_temp_file()
            end)

            it("should error when patterns is not an array", function()
                create_temp_file('{"patterns": "not an array"}')
                
                assert.has_error(function()
                    router_utils.load_patterns_from_file(temp_file_path)
                end, "Invalid route patterns config: missing or invalid 'patterns' array")
                
                cleanup_temp_file()
            end)

            it("should error when pattern is missing regex field", function()
                local json_content = [[{
                    "patterns": [
                        {
                            "name": "test"
                        }
                    ]
                }]]
                
                create_temp_file(json_content)
                
                assert.has_error(function()
                    router_utils.load_patterns_from_file(temp_file_path)
                end, "Invalid pattern at index 1: missing 'regex' or 'name' field")
                
                cleanup_temp_file()
            end)

            it("should error when pattern is missing name field", function()
                local json_content = [[{
                    "patterns": [
                        {
                            "regex": "^/test$"
                        }
                    ]
                }]]
                
                create_temp_file(json_content)
                
                assert.has_error(function()
                    router_utils.load_patterns_from_file(temp_file_path)
                end, "Invalid pattern at index 1: missing 'regex' or 'name' field")
                
                cleanup_temp_file()
            end)

            it("should error when pattern has invalid regex", function()
                local json_content = [[{
                    "patterns": [
                        {
                            "regex": "[invalid regex",
                            "name": "test"
                        }
                    ]
                }]]
                
                create_temp_file(json_content)
                
                assert.has_error(function()
                    router_utils.load_patterns_from_file(temp_file_path)
                end)
                
                cleanup_temp_file()
            end)
        end)
    end)

    describe("get_pattern_from_routes", function()
        describe("happy paths", function()
            it("should find matching pattern", function()
                local result = router_utils.get_pattern_from_routes(valid_config, "/hotels/grand-hotel")
                assert.are.equal("hotels/[name]", result)
            end)

            it("should find first matching pattern when multiple match", function()
                local config_with_overlapping = {
                    patterns = {
                        {
                            regex = "^/api/",
                            name = "api-general"
                        },
                        {
                            regex = "^/api/v(\\d+)/",
                            name = "api/v[version]"
                        }
                    },
                    fallback = "unknown"
                }
                
                local result = router_utils.get_pattern_from_routes(config_with_overlapping, "/api/v1/users")
                assert.are.equal("api-general", result)
            end)

            it("should return fallback when no pattern matches", function()
                local result = router_utils.get_pattern_from_routes(valid_config, "/nonexistent/path")
                assert.are.equal("unknown", result)
            end)

            it("should match search pattern with query string", function()
                local result = router_utils.get_pattern_from_routes(valid_config, "/search?q=hotels")
                assert.are.equal("search", result)
            end)

            it("should match hotels rooms pattern", function()
                local result = router_utils.get_pattern_from_routes(valid_config, "/hotels/grand-hotel/rooms")
                assert.are.equal("hotels/[name]/rooms", result)
            end)

            it("should match API versioned pattern", function()
                local result = router_utils.get_pattern_from_routes(valid_config, "/api/v1/users")
                assert.are.equal("api/v[version]", result)
            end)
        end)

        describe("error cases", function()
            it("should error when routes_config is nil", function()
                assert.has_error(function()
                    router_utils.get_pattern_from_routes(nil, "/test")
                end, "Invalid routes configuration: missing 'patterns' array")
            end)

            it("should error when routes_config is missing patterns", function()
                assert.has_error(function()
                    router_utils.get_pattern_from_routes({}, "/test")
                end, "Invalid routes configuration: missing 'patterns' array")
            end)

            it("should error when uri is nil", function()
                assert.has_error(function()
                    router_utils.get_pattern_from_routes(valid_config, nil)
                end, "No URI provided for pattern matching")
            end)
        end)
    end)
end)