#!/bin/bash

# Test runner script
set -e

echo "Running Sembo CDN tests..."

# Check if busted is available
if ! command -v busted &> /dev/null; then
    echo "Installing busted..."
    luarocks install busted
fi

# Set Lua path
export LUA_PATH="/workspaces/sembo-cdn/nginx/lua/?.lua;/workspaces/sembo-cdn/nginx/lua/?/init.lua;;"

# Run unit tests
echo "Running unit tests..."
cd /workspaces/sembo-cdn
busted tests/unit/ --verbose --pattern=test_

# Run integration tests if services are available
if curl -s http://redis:6379 > /dev/null 2>&1; then
    echo "Running integration tests..."
    busted tests/integration/ --verbose
else
    echo "Skipping integration tests (Redis not available)"
fi

echo "All tests completed!"
