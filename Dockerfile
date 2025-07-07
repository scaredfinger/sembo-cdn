FROM openresty/openresty:latest

# Install minimal runtime dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    && git clone https://github.com/pintsized/lua-resty-http.git \
    && cp lua-resty-http/lib/resty/http* /usr/local/openresty/lualib/resty/ \
    && rm -rf lua-resty-http \
    && git clone https://github.com/openresty/lua-resty-redis.git \
    && cp lua-resty-redis/lib/resty/redis.lua /usr/local/openresty/lualib/resty/ \
    && rm -rf lua-resty-redis \
    && rm -rf /var/lib/apt/lists/*

# Copy configuration and Lua files
COPY nginx/conf/default.conf /etc/nginx/conf.d/default.conf
COPY nginx/conf/variables.conf /etc/nginx/conf.d/variables.main
COPY src/ /usr/local/openresty/nginx/lua/
COPY config/ /usr/local/openresty/nginx/lua/config/

# Create required directories
RUN mkdir -p /usr/local/openresty/nginx/logs

# Default environment variables
ENV REDIS_HOST=redis \
    REDIS_PORT=6379 \
    BACKEND_HOST=backend \
    BACKEND_PORT=80 \
    LOG_LEVEL=info \
    ENV=production

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

EXPOSE 80 9090
CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]
