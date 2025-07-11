# Handlers Documentation

This directory contains the OpenResty request handlers that implement the reverse proxy functionality. Each handler corresponds to a specific nginx location block and provides different capabilities.

## Handler Types

### Management Handlers
Individual files for system management and monitoring:

- **`health.lua`** - System health check endpoint
  - Redis connectivity and performance stats
  - Backend service health monitoring
  - Memory usage and connection status
  - Returns JSON status for load balancer integration

- **`metrics.lua`** - Prometheus metrics endpoint
  - Thread-safe metrics collection from shared memory
  - Standard Prometheus exposition format
  - Request counts, cache performance, response times
  - Route-based analytics and error tracking

- **`play.lua`** - Development and testing endpoint
  - Redis cache testing and validation
  - Development debugging utilities
  - Cache key inspection and manipulation

### Cache Invalidation Handler
- **`invalidate/`** - Cache tag invalidation API
  - `index.lua` - REST API for cache tag operations
  - `handler.lua` - Tag invalidation business logic
  - Supports bulk cache invalidation by tag

### Main Request Handler
- **`main/`** - Primary request processing pipeline
  - `index.lua` - Entry point with full middleware chain
  - `cache.lua` - Cache middleware component initialization
  - `router.lua` - Route pattern detection middleware
  - `surrogate.lua` - Tag-based cache invalidation middleware
  - `metrics.lua` - Performance metrics collection middleware
  - `upstream.lua` - Backend HTTP client configuration

### Shared Utilities
- **`utils/`** - Common functionality shared across handlers
  - `http.lua` - HTTP request/response utilities
  - `cache_provider.lua` - Redis cache provider singleton
  - `tags_provider.lua` - Redis tag provider for surrogate keys
  - `routes.lua` - Route pattern configuration loading

## Request Processing Architecture

The main handler implements a middleware pipeline pattern:

```
Request → Cache → Router → Surrogate → Metrics → Upstream → Response
```

Each middleware component can:
- **Short-circuit** the pipeline (e.g., cache hit)
- **Enhance** the request/response with additional data
- **Collect** metrics and observability information
- **Transform** the request before forwarding

## Nginx Configuration

Map handlers to nginx locations in your configuration:

```nginx
# Management endpoints
location /health {
    content_by_lua_file /usr/local/openresty/nginx/lua/handlers/health.lua;
}

location /metrics {
    content_by_lua_file /usr/local/openresty/nginx/lua/handlers/metrics.lua;
}

location /play {
    content_by_lua_file /usr/local/openresty/nginx/lua/handlers/play.lua;
}

# Cache invalidation API
location ~ ^/cache/tags/(.+)$ {
    content_by_lua_file /usr/local/openresty/nginx/lua/handlers/invalidate/index.lua;
}

# Main proxy handler (catch-all)
location / {
    content_by_lua_file /usr/local/openresty/nginx/lua/handlers/main/index.lua;
}
```

## API Endpoints

### Health Check
```bash
GET /health
```
Returns comprehensive system health status:
```json
{
  "status": "healthy",
  "services": {
    "redis": {"status": "healthy", "stats": {...}},
    "backend": {"status": "healthy", "endpoint": "..."}
  }
}
```

### Metrics
```bash
GET /metrics
```
Returns Prometheus-formatted metrics:
```
# HELP requests_total Total number of requests
# TYPE requests_total counter
requests_total{route="hotel/[name]",method="GET",status="200"} 42
```

### Cache Invalidation
```bash
DELETE /cache/tags/{tag_name}
```
Invalidates all cache entries associated with the specified tag:
```
Invalidated 15 cache entries for tag 'hotel:luxury-resort'
```

### Main Proxy
```bash
GET|POST|PUT|DELETE /*
```
Processes all requests through the middleware pipeline with intelligent caching.

## Development

### Adding New Handlers

1. **Simple Handler**: Create a new `.lua` file in `/handlers/`
2. **Complex Handler**: Create a directory with `index.lua` and supporting files
3. **Update Nginx Config**: Add location block mapping to your handler
4. **Add Tests**: Create corresponding test files in `/tests/unit/handlers/`

### Testing Handlers

```bash
# Test specific handler
curl http://localhost:8080/health

# Test with debug output
curl -v http://localhost:8080/metrics

# Test cache invalidation
curl -X DELETE http://localhost:8080/cache/tags/hotel:luxury-resort
```

### Debugging

Enable debug logging to see handler execution:
```bash
export LOG_LEVEL=debug
docker-compose restart proxy
docker-compose logs -f proxy
```

## Performance Considerations

### Handler Performance
- **Simple handlers**: Sub-millisecond response times
- **Main pipeline**: 1-2ms processing overhead
- **Cache operations**: Redis latency dependent
- **Backend requests**: Network latency dependent

### Resource Usage
- **Memory**: ~10KB per request object
- **Connections**: Shared Redis connection pool
- **CPU**: Minimal processing overhead

## Error Handling

All handlers implement comprehensive error handling:

- **Redis Failures**: Graceful degradation with backend fallback
- **Backend Errors**: Proper HTTP status codes and error messages
- **Configuration Errors**: Startup validation and failure reporting
- **Resource Exhaustion**: Connection pool management and limits

For detailed architecture analysis, see [ai-analysis.md](ai-analysis.md).