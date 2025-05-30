#!/bin/bash

# Development setup script
echo "Setting up Sembo CDN development environment..."

# Create necessary directories
mkdir -p /tmp/nginx
mkdir -p /var/log/nginx

# Set proper permissions
chown -R nobody:nobody /usr/local/openresty/nginx/lua
chmod -R 755 /usr/local/openresty/nginx/lua

# Test Lua syntax
echo "Testing Lua modules..."
for lua_file in /workspace/nginx/lua/modules/*.lua; do
    if [ -f "$lua_file" ]; then
        echo "Checking $lua_file"
        luajit -bl "$lua_file" > /dev/null
        if [ $? -eq 0 ]; then
            echo "✓ $lua_file syntax OK"
        else
            echo "✗ $lua_file syntax ERROR"
        fi
    fi
done

echo "Development setup complete!"
