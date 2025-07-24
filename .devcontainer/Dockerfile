FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    build-essential \
    libpcre3-dev \
    libssl-dev \
    zlib1g-dev \
    libbrotli-dev \
    redis-tools \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    apt-utils \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce-cli docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

RUN add-apt-repository ppa:pi-rho/dev

# Install Lua and LuaRocks
RUN apt-get update \
    && apt-get install -y \
        lua5.1 \
        lua5.1-dev \
        luarocks \
        luajit \
    && rm -rf /var/lib/apt/lists/*

# Install OpenResty libraries for development (not runtime)
RUN luarocks install lua-resty-redis \
    && luarocks install lua-resty-http \
    && luarocks install lua-cjson \
    && luarocks install busted \
    && luarocks install luacheck \
    && luarocks install redis \
    && luarocks install lua-ffi-zlib

RUN git clone https://github.com/sjnam/lua-resty-brotli.git \
    && cp -r lua-resty-brotli/brotli /usr/local/share/lua/5.1/resty/brotli \
    && rm -rf lua-resty-brotli

# Create ubuntu user and add to docker group
RUN useradd -m -s /bin/bash ubuntu \
    && groupadd docker \
    && usermod -aG docker ubuntu
USER ubuntu

# Set environment variables for Lua development
ENV PATH="/usr/local/bin:$PATH"
ENV LUA_PATH="/workspace/nginx/lua/?.lua;/workspace/nginx/lua/?/init.lua;;"
ENV LUA_CPATH="/usr/lib/x86_64-linux-gnu/lua/5.1/?.so;/usr/local/lib/lua/5.1/?.so;;"

# Set working directory
WORKDIR /workspace
