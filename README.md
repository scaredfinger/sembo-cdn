# OpenResty Reverse Proxy

A production-ready reverse proxy built with OpenResty and Lua, featuring advanced caching, metrics collection, and intelligent routing.

## Key Features

- **High-Performance Caching**: Redis-based response caching with HTTP Cache-Control compliance
- **Intelligent Routing**: JSON-configurable URL pattern matching with analytics
- **Comprehensive Metrics**: Prometheus-compatible metrics with detailed performance tracking
- **Middleware Architecture**: Modular, extensible middleware system for request processing
- **Production Ready**: Complete Docker deployment with health monitoring and observability
- **Developer Experience**: Full devcontainer setup with hot-reload and comprehensive testing

## Documentation

- **[Production Readiness Assessment](PRODUCTION_READINESS.md)** - Complete production deployment checklist
- **[Technical Architecture](ai-analysis.md)** - Detailed technical analysis and architecture decisions
- **[Handlers Documentation](src/handlers/README.md)** - Request handlers and routing architecture
- **[Metrics Module](src/modules/metrics/README.md)** - Prometheus metrics collection and export
- **[Surrogate Keys](src/modules/surrogate/README.md)** - Cache invalidation and tag management

## Architecture Overview

The system implements a middleware chain pattern for request processing:

```
Request → Cache → Router → Surrogate → Metrics → Upstream → Response
```

Each middleware can short-circuit the chain (e.g., cache hit) or enhance the request/response before passing control to the next component.

For detailed architecture information, see [Technical Architecture](ai-analysis.md).

## Quick Start

### Development with DevContainer (Recommended)

1. Open project in VS Code with Dev Containers extension
2. Click "Reopen in Container" when prompted
3. Start services: `docker-compose up -d`
4. Test the system: `curl http://localhost:8080/health`

### Production Deployment

```bash
# Build production image
docker build --target production -t reverse-proxy:latest .

# Run with environment configuration
docker run -d \
  --name reverse-proxy \
  -p 80:80 \
  -p 9090:9090 \
  --env-file production.env \
  reverse-proxy:latest
```

For complete production setup, see [Production Readiness Assessment](PRODUCTION_READINESS.md).

## Core Components

### Cache System
- **Redis-based caching** with connection pooling
- **HTTP Cache-Control compliance** (no-cache, no-store, max-age, stale-while-revalidate)
- **Intelligent cache key generation** based on host and path
- **Stale-while-revalidate** support for improved performance

### Metrics Collection
- **Prometheus-compatible metrics** with configurable labels
- **Route-based analytics** with pattern matching
- **Cache performance tracking** (hit/miss ratios, response times)
- **System health monitoring** (Redis, backend, memory usage)

### Routing System
- **JSON-configurable patterns** for URL categorization
- **Regex-based matching** with fallback support
- **Runtime pattern loading** without service restarts
- **Analytics integration** for route performance tracking

### Middleware Architecture
- **Composable middleware chain** for request processing
- **Short-circuit capability** for cache hits and errors
- **Request/response enhancement** at each layer
- **Extensible design** for custom middleware

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `REDIS_HOST` | `127.0.0.1` | Redis server hostname |
| `REDIS_PORT` | `6379` | Redis server port |
| `BACKEND_HOST` | `localhost` | Backend server hostname |
| `BACKEND_PORT` | `8080` | Backend server port |
| `LOG_LEVEL` | `info` | Logging level (debug, info, warn, error) |
| `ROUTE_PATTERNS_FILE` | `/config/route-patterns.json` | Path to route patterns configuration |

### Route Patterns

Configure URL patterns in `/config/route-patterns.json`:

```json
{
  "patterns": [
    {
      "regex": "^/hotel/([^/]+)$",
      "name": "hotel/[name]"
    },
    {
      "regex": "^/api/v(\\d+)/",
      "name": "api/v[version]"
    }
  ],
  "fallback": "unknown"
}
```

## API Endpoints

### Proxy Endpoints
- `GET|POST|PUT|DELETE /*` - Main proxy with intelligent caching

### Management Endpoints
- `GET /health` - System health check with service status
- `GET /metrics` - Prometheus metrics endpoint
- `DELETE /cache/tags/{tag}` - Bulk cache invalidation by tag

## Development

### Testing
```bash
# Run all tests
./scripts/test.sh

# Unit tests only
busted tests/unit/ --verbose

# Integration tests
busted tests/integration/ --verbose
```

### Adding New Middleware
1. Create middleware class implementing `execute(request, next)` method
2. Add to pipeline in `src/handlers/main/index.lua`
3. Register metrics in `src/handlers/metrics/init.lua`
4. Add comprehensive tests

## Monitoring

### Health Check Response
```json
{
  "status": "healthy",
  "timestamp": 1640995200,
  "services": {
    "redis": {
      "status": "healthy",
      "stats": {
        "used_memory_bytes": 1024000,
        "connected": true
      }
    },
    "backend": {
      "status": "healthy",
      "endpoint": "backend:8080"
    }
  }
}
```

### Key Metrics
- `requests_total` - Total requests by route, method, and status
- `cache_hits_total` / `cache_misses_total` - Cache performance
- `response_time_seconds` - Response time histogram
- `backend_errors_total` - Backend error tracking

## License

MIT License - see LICENSE file for details.