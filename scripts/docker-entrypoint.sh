#!/bin/sh
# Custom entrypoint for OpenResty to handle environment variables and configuration

# Ensure we have defaults for required variables
: "${REDIS_HOST:=redis}"
: "${REDIS_PORT:=6379}"
: "${BACKEND_HOST:=backend}"
: "${BACKEND_PORT:=80}"
: "${LOG_LEVEL:=info}"
: "${ENV:=production}"

# Fix the user directive in nginx.conf to use nogroup
sed -i 's/^user nobody;/user nobody nogroup;/' /usr/local/openresty/nginx/conf/nginx.conf

# Create a dynamic upstream configuration file
cat > /usr/local/openresty/nginx/conf/upstream.conf << EOF
upstream backend {
    server $BACKEND_HOST:$BACKEND_PORT max_fails=3 fail_timeout=30s;
    keepalive 32;
}
EOF

# Include the dynamic upstream in http.conf (replace the existing upstream block)
sed -i '/upstream backend {/,/}/d' /usr/local/openresty/nginx/conf/http.conf
echo "include /usr/local/openresty/nginx/conf/upstream.conf;" >> /usr/local/openresty/nginx/conf/http.conf

# Start OpenResty with environment variables available
REDIS_HOST=$REDIS_HOST \
REDIS_PORT=$REDIS_PORT \
BACKEND_HOST=$BACKEND_HOST \
BACKEND_PORT=$BACKEND_PORT \
LOG_LEVEL=$LOG_LEVEL \
ENV=$ENV \
exec "/usr/local/openresty/bin/openresty" "-g" "daemon off;"
