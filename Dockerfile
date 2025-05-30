FROM openresty/openresty:latest AS base

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    redis-tools \
    && rm -rf /var/lib/apt/lists/*

# Install LuaRocks and dependencies
RUN curl -L https://luarocks.org/releases/luarocks-3.9.2.tar.gz | tar xz \
    && cd luarocks-3.9.2 \
    && ./configure --prefix=/usr/local --with-lua=/usr/local/openresty/luajit \
    && make && make install \
    && cd .. && rm -rf luarocks-3.9.2

RUN /usr/local/bin/luarocks install lua-resty-redis
RUN /usr/local/bin/luarocks install lua-cjson

# Development stage
FROM base AS development
RUN /usr/local/bin/luarocks install busted
RUN apt-get update && apt-get install -y git build-essential && rm -rf /var/lib/apt/lists/*
WORKDIR /workspace
CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]

# Production stage
FROM base AS production

# Copy configuration and Lua files
COPY nginx/conf/ /usr/local/openresty/nginx/conf/
COPY nginx/lua/ /usr/local/openresty/nginx/lua/
COPY config/ /usr/local/openresty/nginx/config/

# Set proper permissions
RUN chown -R nobody:nobody /usr/local/openresty/nginx/lua \
    && chmod -R 755 /usr/local/openresty/nginx/lua

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

EXPOSE 80 9090
CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]
