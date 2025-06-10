#!/bin/sh
# Custom entrypoint for OpenResty to handle environment variables and configuration

# Ensure we have defaults for required variables
: "${REDIS_HOST:=redis}"
: "${REDIS_PORT:=6379}"
: "${BACKEND_HOST:=backend-service}"
: "${BACKEND_PORT:=80}"
: "${LOG_LEVEL:=info}"
: "${ENV:=production}"

# Start OpenResty with environment variables available
REDIS_HOST=$REDIS_HOST \
REDIS_PORT=$REDIS_PORT \
BACKEND_HOST=$BACKEND_HOST \
BACKEND_PORT=$BACKEND_PORT \
LOG_LEVEL=$LOG_LEVEL \
ENV=$ENV \
exec "/usr/local/openresty/bin/openresty" "-g" "daemon off;"
