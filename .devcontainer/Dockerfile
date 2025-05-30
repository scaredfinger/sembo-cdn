FROM openresty/openresty:latest

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    build-essential \
    redis-tools \
    && rm -rf /var/lib/apt/lists/*

# Install LuaRocks
RUN curl -L https://luarocks.org/releases/luarocks-3.9.2.tar.gz | tar xz \
    && cd luarocks-3.9.2 \
    && ./configure --prefix=/usr/local --with-lua=/usr/local/openresty/luajit \
    && make && make install \
    && cd .. && rm -rf luarocks-3.9.2

# Install Lua testing framework and Redis client
RUN /usr/local/bin/luarocks install busted
RUN /usr/local/bin/luarocks install lua-resty-redis
RUN /usr/local/bin/luarocks install lua-cjson

# Set working directory
WORKDIR /workspace

# Copy project files (will be mounted in dev)
COPY . .

# Set environment variables
ENV PATH="/usr/local/bin:$PATH"
ENV LUA_PATH="/workspace/nginx/lua/?.lua;/workspace/nginx/lua/?/init.lua;;"

# Default command
CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]
