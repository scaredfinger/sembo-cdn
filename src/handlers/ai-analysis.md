# Handlers Analysis

## Architecture Pattern
OpenResty `content_by_lua` entrypoints following location-based routing:
- Simple endpoints: single `.lua` files  
- Complex endpoints: folders with `index.lua`
- Component initialization: files alongside `index.lua`
- Shared utilities: `utils/*`

## Current Structure

### Simple Entrypoints
- `health.lua` - Redis health check + stats endpoint
- `metrics.lua` - Prometheus metrics output  
- `play.lua` - Redis cache testing endpoint

### Complex Entrypoint  
- `main/` - Primary request handler with middleware chain
  - `index.lua` - Entry point orchestrating cache → router → surrogate → upstream
  - `cache.lua` - Caching middleware component
  - `router.lua` - Routing middleware component  
  - `surrogate.lua` - Surrogate key handling component
  - `upstream.lua` - Upstream request execution

### Shared Utilities
- `utils/http.lua` - HTTP request/response handling
- `utils/cache_provider.lua` - Cache provider abstraction
- `utils/tags_provider.lua` - Tags provider abstraction

## Request Flow
main → cache → router → surrogate → upstream (reverse proxy chain)

## Observations
- Clean separation of concerns
- Middleware pattern implementation
- Shared utilities properly isolated
- Redis-based caching and surrogate key management
- Prometheus metrics integration