FROM ubuntu:22.04

# Install system dependencies and Docker CLI
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    build-essential \
    libpcre3-dev \
    libssl-dev \
    zlib1g-dev \
    redis-tools \
    ca-certificates \
    gnupg \
    lsb-release \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce-cli docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# Install LuaJIT
RUN curl -L https://luajit.org/download/LuaJIT-2.1.0-beta3.tar.gz | tar xz \
    && cd LuaJIT-2.1.0-beta3 \
    && make && make install \
    && cd .. && rm -rf LuaJIT-2.1.0-beta3 \
    && ln -sf luajit-2.1.0-beta3 /usr/local/bin/luajit

# Install LuaRocks
RUN curl -L https://luarocks.org/releases/luarocks-3.9.2.tar.gz | tar xz \
    && cd luarocks-3.9.2 \
    && ./configure --prefix=/usr/local --with-lua-include=/usr/local/include/luajit-2.1 \
    && make && make install \
    && cd .. && rm -rf luarocks-3.9.2

# Install OpenResty libraries for development (not runtime)
RUN luarocks install lua-resty-redis \
    && luarocks install lua-resty-http \
    && luarocks install lua-cjson \
    && luarocks install busted \
    && luarocks install luacheck

# Set working directory
WORKDIR /workspace

# Set environment variables for Lua development
ENV PATH="/usr/local/bin:$PATH"
ENV LUA_PATH="/workspace/nginx/lua/?.lua;/workspace/nginx/lua/?/init.lua;;"
ENV LUA_CPATH="/usr/local/lib/lua/5.1/?.so;;"

# Default command for development
CMD ["/bin/bash"]
