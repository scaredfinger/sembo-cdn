# Sembo CDN - OpenResty Reverse Proxy

A high-performance reverse proxy built with OpenResty and Lua, featuring advanced caching, metrics collection, and route pattern analysis.

## Features

- **Advanced Response Caching**: Redis-based response caching with Cache-Control header parsing and stale-while-revalidate support
- **Comprehensive Metrics**: Prometheus-compatible metrics with route pattern analysis and performance tracking
- **Intelligent Route Matching**: JSON-configurable URL pattern detection (e.g., `/hotel/luxury-resort` → `hotel/[name]`)
- **Health Monitoring**: Real-time health checks for Redis, backend services, and system status
- **Cache Control Compliance**: Full HTTP Cache-Control directive support (no-cache, no-store, max-age, stale-while-revalidate)
- **Middleware Architecture**: Modular middleware system for extensible request/response processing
- **Development Ready**: Complete devcontainer setup with hot-reload and WireMock backend
- **Testing Suite**: Comprehensive unit and integration tests with busted framework

## Quick Start

### Using Docker Compose

```bash
# Clone the repository
git clone https://github.com/scaredfinger/sembo-cdn.git
cd sembo-cdn

# Start all services
docker-compose up -d

# Test the proxy
curl http://localhost:8080/health

# Check metrics
curl http://localhost:9090/metrics
```

### Using DevContainer

1. Open the project in VS Code
2. Click "Reopen in Container" when prompted
3. Wait for the container to build and start
4. Run tests: `./scripts/test.sh`

## Architecture

```
┌─────────────┐    ┌─────────────────┐    ┌─────────────┐
│   Client    │───>│   Sembo CDN     │───>│  Backend    │
│             │    │                 │    │ (WireMock)  │
└─────────────┘    │ ┌──────────────┐│    └─────────────┘
                   │ │Cache         ││
                   │ │Middleware    ││    ┌─────────────┐
                   │ └──────────────┘│───>│    Redis    │
                   │ ┌──────────────┐│    │   (Cache)   │
                   │ │Router        ││    └─────────────┘
                   │ │Middleware    ││
                   │ └──────────────┘│    ┌─────────────┐
                   │ ┌──────────────┐│───>│  Metrics    │
                   │ │HTTP Upstream ││    │(Prometheus) │
                   │ └──────────────┘│    └─────────────┘
                   └─────────────────┘
```

## Components

### Core Modules

- **`modules/config.lua`**: Environment-based configuration management with validation
- **`modules/cache/`**: Comprehensive caching system with Redis provider and middleware
  - **`middleware.lua`**: Cache-Control compliant response caching middleware
  - **`providers/redis_cache_provider.lua`**: Redis implementation with connection pooling
  - **`cache_control_parser.lua`**: HTTP Cache-Control header parsing
  - **`key_strategy_host_path.lua`**: Cache key generation strategy
- **`modules/metrics.lua`**: In-memory metrics collection and Prometheus formatting
- **`modules/router/`**: URL pattern matching system
  - **`middleware.lua`**: Route pattern detection middleware
  - **`utils.lua`**: Pattern loading and matching utilities
- **`modules/http/`**: HTTP abstraction layer
  - **`request.lua`**: Request object model
  - **`response.lua`**: Response object model
  - **`upstream.lua`**: HTTP client for backend communication
  - **`handler.lua`**: Base handler interface
  - **`middleware.lua`**: Base middleware interface
- **`modules/utils.lua`**: Shared utility functions and logging

### Handlers

- **`handlers/main/index.lua`**: Main request processing entry point
- **`handlers/main/cache.lua`**: Cache middleware initialization
- **`handlers/main/upstream.lua`**: Backend communication setup
- **`handlers/health.lua`**: Health check endpoint with Redis and backend status
- **`handlers/metrics.lua`**: Metrics endpoint for Prometheus scraping
- **`handlers/play.lua`**: Development and testing handler

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `REDIS_HOST` | `127.0.0.1` | Redis server hostname |
| `REDIS_PORT` | `6379` | Redis server port |
| `BACKEND_HOST` | `localhost` | Backend server hostname |
| `BACKEND_PORT` | `8080` | Backend server port |
| `BACKEND_HEALTHCHECK_PATH` | `` | Backend health check endpoint path |
| `ROUTE_PATTERNS_FILE` | `/usr/local/openresty/nginx/lua/config/route-patterns.json` | Path to route patterns configuration file |
| `LOG_LEVEL` | `info` | Logging level (debug, info, warn, error) |
| `ENV` | `production` | Environment mode (development, production) |

### Route Patterns

The proxy uses a JSON configuration file to define URL patterns for metrics categorization. Create or edit `/config/route-patterns.json`:

```json
{
  "patterns": [
    {
      "regex": "^/hotel/([^/]+)$",
      "name": "hotel/[name]"
    },
    {
      "regex": "^/hotel/([^/]+)/rooms$",
      "name": "hotel/[name]/rooms"
    },
    {
      "regex": "^/hotel/([^/]+)/rooms/([^/]+)$",
      "name": "hotel/[name]/rooms/[id]"
    },
    {
      "regex": "^/api/v(\\d+)/",
      "name": "api/v[version]"
    },
    {
      "regex": "^/search\\?",
      "name": "search"
    }
  ],
  "fallback": "unknown"
}
```

Patterns are matched in order - first match wins. The proxy automatically detects and categorizes URLs:

- `/hotel/luxury-resort` → `hotel/[name]`
- `/hotel/beach-hotel/rooms` → `hotel/[name]/rooms`
- `/hotel/grand-palace/rooms/101` → `hotel/[name]/rooms/[id]`
- `/api/v1/users` → `api/v[version]`
- `/search?q=hotels` → `search`
- `/unknown/path` → `unknown` (fallback)

## Endpoints

### Proxy Endpoints

- **`GET /*`**: Proxies all requests to backend with intelligent caching based on Cache-Control headers
- **`POST|PUT|DELETE /*`**: Proxies all non-GET requests to backend (bypasses cache)

### Management Endpoints

- **`GET /health`**: Comprehensive health check with Redis, backend, and system status
- **`GET /metrics`**: Prometheus-compatible metrics endpoint (port 80 and optionally 9090)
- **`GET /play`**: Development endpoint for testing cache and Redis connectivity

## Caching Strategy

### Cache-Control Support

The proxy fully supports HTTP Cache-Control directives:

- **`no-cache`**: Bypasses cache, always fetches from backend
- **`no-store`**: Does not cache the response
- **`max-age=N`**: Caches response for N seconds
- **`stale-while-revalidate=N`**: Serves stale content while revalidating for N additional seconds
- **`public`**: Allows shared caching (default behavior)
- **`private`**: Prevents caching (treated as no-store)

### Cache Key Strategy

Cache keys are generated using: `{method}:{host}:{path}` format for consistent cache behavior.

### Redis Configuration

- Connection pooling with configurable timeouts
- Automatic reconnection handling
- Graceful degradation when Redis is unavailable

## Metrics

The proxy collects comprehensive metrics in Prometheus format:

- **`requests_total`**: Total requests by route, method, and status
- **`cache_hits_total`**: Cache hits by route pattern
- **`cache_misses_total`**: Cache misses by route pattern
- **`backend_errors_total`**: Backend errors by route pattern
- **`response_time_seconds`**: Response time histogram

## Development

### Running Tests

```bash
# All tests with the included script
./scripts/test.sh

# Unit tests only
cd /workspaces/sembo-cdn
export LUA_PATH="./src/?.lua;./src/?/init.lua;;"
busted tests/unit/ --verbose --pattern=test_

# Integration tests (requires running Redis)
busted tests/integration/ --verbose
```

### Development Workflow

1. Open project in VS Code with Dev Containers extension
2. Reopen in container when prompted
3. Start services: `docker-compose up -d`
4. Make changes to Lua modules in `src/`
5. Test changes: `./scripts/test.sh`
6. Restart proxy for changes: `docker-compose restart proxy`
7. Verify functionality: `curl http://localhost:8080/health`

### Development Endpoints

- **Proxy**: `http://localhost:8080/`
- **Health Check**: `http://localhost:8080/health`
- **Metrics**: `http://localhost:8080/metrics`
- **Development Playground**: `http://localhost:8080/play`
- **Redis Insight**: `http://localhost:5540` (Redis management UI)

### Adding New Route Patterns

Edit the route patterns configuration file at `/config/route-patterns.json`:

```json
{
  "patterns": [
    {
      "regex": "^/bookings/([^/]+)$",
      "name": "bookings/[id]"
    },
    {
      "regex": "^/users/([^/]+)/preferences$",
      "name": "users/[id]/preferences"
    }
  ],
  "fallback": "unknown"
}
```

Restart the service to load new patterns:
```bash
docker-compose restart proxy
```

### Testing Cache Behavior

```bash
# Test cache miss (first request)
curl -v http://localhost:8080/hotel/luxury-resort

# Test cache hit (subsequent request)
curl -v http://localhost:8080/hotel/luxury-resort

# Check cache metrics
curl http://localhost:8080/metrics | grep cache
```

## Monitoring

### Health Check Response

```json
{
  "status": "healthy",
  "timestamp": 1640995200,
  "version": "1.0.0",
  "services": {
    "redis": {
      "status": "healthy",
      "message": "Connected and responsive",
      "endpoint": "redis:6379",
      "timeout_ms": 1000,
      "stats": {
        "used_memory_bytes": 1024000,
        "used_memory_human": "1000K",
        "max_memory_bytes": 0,
        "connected": true
      }
    },
    "backend": {
      "status": "healthy",
      "endpoint": "wiremock:8080",
      "message": "Backend is responsive",
      "health_check": {
        "enabled": true,
        "path": "/__admin/health"
      }
    }
  }
}
```

### Prometheus Metrics Example

```
# HELP requests_total Total number of requests
# TYPE requests_total counter
requests_total{route="hotel/[name]",method="GET",status="200"} 42

# HELP cache_hits_total Total number of cache hits
# TYPE cache_hits_total counter
cache_hits_total{route="hotel/[name]"} 28

# HELP cache_misses_total Total number of cache misses
# TYPE cache_misses_total counter
cache_misses_total{route="hotel/[name]"} 14

# HELP backend_errors_total Total number of backend errors
# TYPE backend_errors_total counter
backend_errors_total{route="api/v[version]"} 2

# HELP response_time_seconds Response time histogram
# TYPE response_time_seconds histogram
response_time_seconds_sum 125.6
response_time_seconds_count 42
```

## Production Deployment

### Docker

```bash
# Build production image
docker build --target production -t sembo-cdn:latest .

# Run with production config
docker run -d \\
  --name sembo-cdn \\
  -p 80:80 \\
  -p 9090:9090 \\
  --env-file config/environments/production.env \\
  sembo-cdn:latest
```

### Environment Setup

1. Configure Redis cluster for high availability
2. Set up Prometheus to scrape metrics from `:9090/metrics`
3. Configure log aggregation for JSON-formatted access logs
4. Set up health check monitoring on `/health`

## Troubleshooting

### Common Issues

**Cache not working**
- Check Redis connectivity: `curl http://localhost:8080/health`
- Verify Redis configuration in environment variables
- Check Cache-Control headers from backend: `curl -v http://localhost:8080/hotel/luxury-resort`

**High response times**
- Check backend health via health endpoint
- Monitor Redis memory usage in health check
- Review cache hit rates in metrics: `curl http://localhost:8080/metrics | grep cache`

**Route patterns not matching**
- Verify pattern syntax in `/config/route-patterns.json`
- Test patterns in isolation using test suite
- Check logs for pattern loading errors: `docker-compose logs proxy`

**Metrics not updating**
- Verify shared dictionary configuration in nginx
- Check Lua module syntax errors in logs
- Ensure metrics endpoint is accessible: `curl http://localhost:8080/metrics`

### Debugging

Enable debug logging:
```bash
# Update environment in docker-compose.yml
- LOG_LEVEL=debug

# Restart to apply changes
docker-compose restart proxy
```

Check logs:
```bash
# Follow proxy logs
docker-compose logs -f proxy

# Check specific issues
docker-compose logs proxy | grep -i error
docker-compose logs proxy | grep -i cache
```

Test individual components:
```bash
# Test Redis connection
docker-compose exec redis redis-cli ping

# Test backend health (WireMock admin)
curl http://localhost:8080/__admin/health

# Test route pattern matching
curl http://localhost:8080/play
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes with tests
4. Run the test suite
5. Submit a pull request

## License

MIT License - see LICENSE file for details.
"