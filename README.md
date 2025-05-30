# Sembo CDN - OpenResty Reverse Proxy

A high-performance reverse proxy built with OpenResty and Lua, featuring advanced caching, metrics collection, and route pattern analysis.

## Features

- **Advanced Caching**: Redis-based response caching with configurable TTL
- **Metrics Collection**: Prometheus-compatible metrics with route pattern analysis
- **Route Pattern Matching**: Intelligent URL pattern detection (e.g., `/hotels/lorem-ipsum` → `hotels/[name]`)
- **Health Monitoring**: Comprehensive health checks for all components
- **Development Ready**: Full devcontainer and Docker Compose setup
- **Testing**: Complete unit and integration test suite

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
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Client    │───▶│ Sembo CDN   │───▶│  Backend    │
└─────────────┘    └─────────────┘    └─────────────┘
                          │
                          ▼
                   ┌─────────────┐
                   │    Redis    │
                   │   (Cache)   │
                   └─────────────┘
```

## Components

### Core Modules

- **`modules/cache.lua`**: Redis-based caching with connection pooling
- **`modules/metrics.lua`**: In-memory metrics collection and Prometheus formatting
- **`modules/router.lua`**: URL pattern matching for analytics
- **`modules/utils.lua`**: Shared utility functions

### Handlers

- **`handlers/proxy.lua`**: Main request proxying logic
- **`handlers/health.lua`**: Health check endpoint
- **`handlers/metrics.lua`**: Metrics endpoint for Prometheus

### Configuration

- **Environment Variables**: Primary configuration method
- **Route Patterns**: Configurable URL pattern matching
- **Redis Settings**: Connection and caching configuration

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `REDIS_HOST` | `127.0.0.1` | Redis server hostname |
| `REDIS_PORT` | `6379` | Redis server port |
| `BACKEND_HOST` | `localhost` | Backend server hostname |
| `BACKEND_PORT` | `3000` | Backend server port |
| `LOG_LEVEL` | `info` | Logging level (debug, info, warn, error) |

### Route Patterns

The proxy automatically detects and categorizes URLs for metrics:

- `/hotels/luxury-resort` → `hotels/[name]`
- `/hotels/beach-hotel/rooms` → `hotels/[name]/rooms`
- `/api/v1/users` → `api/v[version]`
- `/users/12345` → `users/[id]`

## Endpoints

### Proxy Endpoints

- **`GET /*`**: Proxies all requests to backend with caching
- **`POST /*`**: Proxies all requests to backend (no caching)

### Management Endpoints

- **`GET /health`**: Health check with service status
- **`GET /metrics`**: Prometheus-compatible metrics (ports 80 and 9090)

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
# Unit tests only
./scripts/test.sh

# Or manually with busted
export LUA_PATH=\"./nginx/lua/?.lua;./nginx/lua/?/init.lua;;\"
busted tests/unit/ --verbose
```

### Development Workflow

1. Make changes to Lua modules
2. Test changes: `./scripts/test.sh`
3. Restart services: `docker-compose restart proxy`
4. Verify functionality: `curl http://localhost:8080/health`

### Adding New Route Patterns

Edit `nginx/lua/modules/router.lua`:

```lua
local patterns = {
    {
        pattern = \"^/new-pattern/([^/]+)$\",
        name = \"new-pattern/[id]\"
    }
}
```

## Monitoring

### Health Check Response

```json
{
  \"status\": \"healthy\",
  \"timestamp\": 1640995200,
  \"version\": \"1.0.0\",
  \"services\": {
    \"redis\": {
      \"status\": \"healthy\",
      \"message\": \"healthy\"
    },
    \"backend\": {
      \"status\": \"healthy\",
      \"endpoint\": \"backend:80\"
    }
  },
  \"cache_stats\": {
    \"used_memory\": \"1024000\",
    \"used_memory_human\": \"1000K\",
    \"connected\": true
  }
}
```

### Prometheus Metrics Example

```
# HELP requests_total Total number of requests
# TYPE requests_total counter
requests_total{route=\"hotels/[name]\",method=\"GET\",status=\"200\"} 42

# HELP cache_hits_total Total number of cache hits
# TYPE cache_hits_total counter
cache_hits_total{route=\"hotels/[name]\"} 28
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

**High response times**
- Check backend health
- Monitor Redis memory usage
- Review cache hit rates in metrics

**Metrics not updating**
- Verify shared dictionary size in nginx configuration
- Check Lua module syntax: `./scripts/dev-setup.sh`

### Debugging

Enable debug logging:
```bash
export LOG_LEVEL=debug
docker-compose restart proxy
```

Check logs:
```bash
docker-compose logs -f proxy
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