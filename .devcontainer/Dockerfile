FROM ubuntu:24.10

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

# Install Lua and LuaRocks
RUN apt-get update && apt-get install -y \
    lua5.1 \
    lua5.1-dev \
    luarocks \
    && rm -rf /var/lib/apt/lists/*

# Install OpenResty libraries for development (not runtime)
RUN luarocks install lua-resty-redis \
    && luarocks install lua-resty-http \
    && luarocks install lua-cjson \
    && luarocks install busted \
    && luarocks install luacheck \
    && luarocks install redis


RUN groupadd docker && usermod -aG docker ubuntu
USER ubuntu

# Set environment variables for Lua development
ENV PATH="/usr/local/bin:$PATH"
ENV LUA_PATH="/workspace/nginx/lua/?.lua;/workspace/nginx/lua/?/init.lua;;"
ENV LUA_CPATH="/usr/lib/x86_64-linux-gnu/lua/5.1/?.so;/usr/local/lib/lua/5.1/?.so;;"

# Set working directory
WORKDIR /workspace
