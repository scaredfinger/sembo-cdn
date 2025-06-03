FROM openresty/openresty:latest

# Install minimal runtime dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy configuration and Lua files
COPY nginx/conf/ /usr/local/openresty/nginx/conf/
COPY nginx/lua/ /usr/local/openresty/nginx/lua/
COPY scripts/docker-entrypoint.sh /docker-entrypoint.sh

# Set proper permissions
RUN chmod +x /docker-entrypoint.sh && \
    mkdir -p /usr/local/openresty/nginx/logs

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
ENTRYPOINT ["/docker-entrypoint.sh"]
