#!/bin/sh
# Custom entrypoint for OpenResty to handle environment variables and configuration

# Ensure we have defaults for required variables
: "${REDIS_HOST:=redis}"
: "${REDIS_PORT:=6379}"
: "${BACKEND_HOST:=backend-service}"
: "${BACKEND_PORT:=80}"
: "${LOG_LEVEL:=info}"
: "${ENV:=production}"

Create a dynamic upstream configuration file
echo "
upstream backend-service {
    server $BACKEND_HOST:$BACKEND_PORT max_fails=3 fail_timeout=30s;
    keepalive 32;
}
" > /etc/nginx/conf.d/upstream.conf

# Start OpenResty with environment variables available
REDIS_HOST=$REDIS_HOST \
REDIS_PORT=$REDIS_PORT \
BACKEND_HOST=$BACKEND_HOST \
BACKEND_PORT=$BACKEND_PORT \
LOG_LEVEL=$LOG_LEVEL \
ENV=$ENV \
exec "/usr/local/openresty/bin/openresty" "-g" "daemon off;"
