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
export LUA_PATH="/workspace/nginx/lua/?.lua;/workspace/nginx/lua/?/init.lua;;"

# Run unit tests
echo "Running unit tests..."
cd /workspace
busted tests/unit/ --verbose

# Run integration tests if services are available
if curl -s http://redis:6379 > /dev/null 2>&1; then
    echo "Running integration tests..."
    busted tests/integration/ --verbose
else
    echo "Skipping integration tests (Redis not available)"
fi

echo "All tests completed!"
