# OpenResty Reverse Proxy - AI Analysis Document

## Project Overview
Building a reverse proxy using OpenResty and Lua with advanced caching and metrics capabilities beyond nginx's default functionality.

## Technical Requirements

### Core Functionality
- **Caching**: Response caching using Redis (more advanced than nginx default)
- **Metrics**: Custom metrics collection and analysis
- **Backend**: Single backend initially (design allows for multiple if simple)
- **Configuration**: 100% static configuration
- **Route Analysis**: Measure requests by REST path patterns (e.g., `/hotels/lorem-ipsum` counted as `hotels/[name]`)

### Technology Stack
- **OpenResty**: Nginx + Lua runtime
- **Redis**: Only external service for response caching
- **Lua**: Custom modules for business logic
- **Docker**: Deployment target
- **Devcontainers**: Development environment

### Deployment & Configuration
- **Deployment**: Docker-based
- **Configuration**: Environment variables (as simple as possible)
- **Environments**: Support for dev/staging/prod
- **No external services**: Except Redis

### Metrics Specifications
- **Storage**: In-memory (not Redis)
- **Format**: Prometheus format
- **Endpoint**: `/metrics` HTTP endpoint
- **Pattern Matching**: Configuration-driven route patterns

### Caching Specifications
- **Type**: Response caching only (not request/upstream)
- **Storage**: Redis
- **Strategy**: Static configuration

## Project Structure
```
sembo-cdn/
├── .devcontainer/
│   ├── devcontainer.json
│   └── Dockerfile
├── docker-compose.yml
├── docker-compose.dev.yml
├── Dockerfile
├── nginx/
│   └── conf/
│       ├── nginx.conf
│       ├── http.conf
│       └── server.conf
├── src/
│   ├── init.lua
│   ├── modules/
│   │   ├── cache.lua
│   │   ├── metrics.lua
│   │   ├── router.lua
│   │   └── utils.lua
│   └── handlers/
│       ├── proxy.lua
│       └── health.lua
├── tests/
│   ├── unit/
│   │   ├── test_cache.lua
│   │   ├── test_metrics.lua
│   │   └── test_router.lua
│   ├── integration/
│   │   └── test_proxy.lua
│   └── fixtures/
│       └── sample_responses.json
├── scripts/
│   ├── test.sh
│   └── dev-setup.sh
├── config/
│   ├── redis.conf
│   └── environments/
│       ├── development.env
│       └── production.env
└── README.md
```

## Module Design

### Lua Modules
- **cache.lua**: Redis operations for response caching
- **metrics.lua**: In-memory metrics collection and Prometheus formatting
- **router.lua**: Path pattern matching for analytics (`/hotels/[name]` detection)
- **utils.lua**: Shared utilities
- **proxy.lua**: Main proxy handler
- **health.lua**: Health check endpoints

### Testing Framework
- **Framework**: busted (Lua testing framework)
- **Types**: Unit tests and integration tests
- **Coverage**: All Lua modules

## Development Environment
- **Devcontainers**: Pre-configured with OpenResty, Redis, Lua testing tools
- **Docker Compose**: Development and testing setup
- **Scripts**: Automated testing and development setup

## Configuration Strategy
- **Environment Variables**: Primary configuration method
- **Pattern Configuration**: File-based route pattern definitions
- **Redis Configuration**: Environment-driven connection settings
- **Backend Configuration**: Static upstream definitions

## Key Design Decisions
1. **Separation of Concerns**: Clear module boundaries
2. **Environment-Driven**: Configuration via env vars
3. **Testing-First**: Comprehensive test coverage
4. **Development-Friendly**: Devcontainer setup
5. **Production-Ready**: Docker deployment target

## Developer Profile
- **Experience**: 25+ years software development
- **Expertise**: Very experienced with complex system architecture
- **Preferences**: Clean structure, testable code, minimal complexity
- **Approach**: Incremental development with testable states

## Implementation Notes
- Start with core structure and basic functionality
- Implement in small, testable increments
- Use standard commit conventions (feat/, chore/, doc/)
- Verify file existence before modifications
- Follow existing patterns when extending functionality
