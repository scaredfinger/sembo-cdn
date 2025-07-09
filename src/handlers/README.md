# Handlers Directory

This directory contains OpenResty `content_by_lua` entrypoints that map to nginx location blocks.

## Structure

### Simple Endpoints
Individual `.lua` files for straightforward handlers:

- **`health.lua`** - Health check endpoint with Redis connectivity and memory stats
- **`metrics.lua`** - Prometheus metrics endpoint  
- **`play.lua`** - Development/testing endpoint for Redis cache operations

### Complex Endpoints
Folders with `index.lua` for multi-component handlers:

- **`main/`** - Primary request processing pipeline
  - `index.lua` - Main entry point
  - `cache.lua`, `router.lua`, `surrogate.lua`, `upstream.lua` - Pipeline components

### Shared Utilities
- **`utils/`** - Common functionality shared across handlers
  - `http.lua` - HTTP request/response utilities
  - `cache_provider.lua` - Cache abstraction
  - `tags_provider.lua` - Tags management abstraction

## Usage

Map nginx locations to handlers:
```nginx
location /health { content_by_lua_file handlers/health.lua; }
location /metrics { content_by_lua_file handlers/metrics.lua; }  
location / { content_by_lua_file handlers/main/index.lua; }
```

## Architecture

The main handler implements a middleware chain pattern:
**Request** → **Cache** → **Router** → **Surrogate** → **Upstream** → **Response**

Each component can short-circuit the chain (e.g., cache hit) or pass control to the next component.