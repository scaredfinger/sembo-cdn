# Metrics Module

A thread-safe Prometheus metrics module for OpenResty/nginx environments, supporting both histogram and counter metrics with race condition protection.

## Features

- **Thread-Safe**: Uses atomic operations to prevent race conditions in multi-worker environments
- **Histogram & Counter Support**: Specialized for both histogram and counter metrics
- **Label Support**: Full support for metric labels with automatic key generation
- **Prometheus Compatible**: Generates standard Prometheus exposition format
- **Memory Efficient**: Pre-initializes metrics to avoid runtime allocation issues

## Quick Start

```lua
local Metrics = require "modules.metrics.index"

-- Initialize with OpenResty shared dictionary
local metrics = Metrics.new(ngx.shared.metrics)

-- Register a counter with expected label combinations
metrics:register_counter(
    "http_requests_total",
    "Total HTTP requests",
    {"method", "route"},
    {
        method={"GET", "POST", "PUT"},
        route={"/api/users", "/api/orders", "/health"}
    }
)

-- Register a histogram with expected label combinations
metrics:register_histogram(
    "response_time_seconds",
    "HTTP response time in seconds",
    {"method", "route"},
    {
        method={"GET", "POST"},
        route={"/api/users", "/api/health"}
    },
    {0.1, 0.5, 1.0, 2.5, 5.0}  -- custom buckets
)

-- Increment counters
metrics:inc_counter("http_requests_total", 1, {
    method="GET", 
    route="/api/users"
})

-- Record histogram observations
metrics:observe_histogram("response_time_seconds", 0.125, {
    method="GET", 
    route="/api/users"
})

-- Generate Prometheus output
local output = metrics:generate_prometheus()
```

## API Reference

### Constructor

#### `Metrics.new(metrics_dict)`
Creates a new metrics instance.

**Parameters:**
- `metrics_dict`: OpenResty shared dictionary (e.g., `ngx.shared.metrics`)

**Returns:** Metrics instance or nil if dictionary unavailable

### Counter Methods

#### `metrics:register_counter(name, help, label_names, label_values)`
Registers a counter metric with pre-defined label combinations.

**Parameters:**
- `name` (string): Metric name
- `help` (string): Help text for Prometheus
- `label_names` (optional): Array of label names
- `label_values` (optional): Table of label value arrays

**Example:**
```lua
metrics:register_counter(
    "http_requests_total",
    "Total HTTP requests",
    {"method", "status"},
    {
        method={"GET", "POST"},
        status={"200", "404", "500"}
    }
)
```

#### `metrics:inc_counter(name, value, labels)`
Increments a counter.

**Parameters:**
- `name` (string): Metric name
- `value` (optional, default=1): Increment value
- `labels` (optional): Table of label key-value pairs

**Example:**
```lua
metrics:inc_counter("http_requests_total", 1, {
    method="GET", 
    status="200"
})
```

### Histogram Methods

#### `metrics:register_histogram(name, help, label_names, label_values, buckets)`
Registers a histogram metric with pre-defined label combinations.

**Parameters:**
- `name` (string): Metric name
- `help` (string): Help text for Prometheus
- `label_names` (optional): Array of label names
- `label_values` (optional): Table of label value arrays
- `buckets` (optional): Array of bucket boundaries

**Example:**
```lua
metrics:register_histogram(
    "request_duration",
    "Request duration in seconds",
    {"method", "status"},
    {
        method={"GET", "POST"}, 
        status={"200", "404"}
    },
    {0.1, 0.5, 1.0, 2.5, 5.0}
)
```

#### `metrics:observe_histogram(name, value, labels)`
Records a histogram observation.

**Parameters:**
- `name` (string): Metric name
- `value` (number): Observed value
- `labels` (optional): Table of label key-value pairs

**Example:**
```lua
metrics:observe_histogram("request_duration", 0.05, {
    method="GET", 
    status="200"
})
```

#### `metrics:generate_prometheus()`
Generates Prometheus exposition format output.

**Returns:** String containing Prometheus metrics

#### `metrics:get_summary()`
Returns current metrics summary (useful for debugging).

**Returns:** Table with all current metric values

## Configuration

Add to your `nginx.conf`:

```nginx
lua_shared_dict metrics 10m;
```

## Race Condition Protection

This module prevents race conditions through:

1. **Pre-initialization**: All metric keys are initialized to 0 during registration
2. **Atomic Operations**: Only atomic `incr` operations are used for observations
3. **No Fallback Logic**: Eliminates "check-then-set" patterns that cause races

## Best Practices

### 1. Register Metrics Early
```lua
-- Register all metrics during application startup
metrics:register_counter("api_requests_total", "API requests", 
    {"endpoint"}, {endpoint={"/users", "/orders"}})
    
metrics:register_histogram("api_response_time", "API response time", 
    {"endpoint"}, {endpoint={"/users", "/orders"}})
```

### 2. Pre-define Label Combinations
```lua
-- Define expected label combinations to avoid runtime allocation
local endpoints = {"/api/users", "/api/orders", "/health"}
local methods = {"GET", "POST", "PUT", "DELETE"}

metrics:register_counter("request_count", "Request count", 
    {"method", "endpoint"}, {method=methods, endpoint=endpoints})
```

### 3. Use Consistent Label Names
```lua
-- Good: consistent label names
metrics:observe_histogram("response_time", 0.1, {method="GET", route="/api"})
metrics:observe_histogram("response_time", 0.2, {method="POST", route="/api"})

-- Bad: inconsistent label names
metrics:observe_histogram("response_time", 0.1, {http_method="GET"})
metrics:observe_histogram("response_time", 0.2, {method="POST"})
```

## Performance Considerations

- **Label Cardinality**: Keep label combinations reasonable (< 1000 per metric)
- **Memory Usage**: Monitor shared dictionary usage with many metrics
- **Observation Frequency**: Module is optimized for high-frequency observations

## Integration

### HTTP Handler
```lua
-- src/handlers/metrics/index.lua
local Metrics = require "modules.metrics.index"
local metrics = Metrics.new(ngx.shared.metrics)

ngx.header["Content-Type"] = "text/plain; version=0.0.4; charset=utf-8"
ngx.say(metrics:generate_prometheus())
```

### Application Integration
```lua
-- In your application handlers
local metrics = Metrics.new(ngx.shared.metrics)

-- Register metrics during init
metrics:register_histogram("request_duration", "Request duration", 
    {"route"}, {{route="/api/users"}})

-- Use in request handlers
local start_time = ngx.now()
-- ... handle request ...
local duration = ngx.now() - start_time
metrics:observe_histogram("request_duration", duration, {route="/api/users"})
```

## Testing

The module includes comprehensive test coverage:

```bash
# Run tests
busted tests/unit/test_metrics.lua
```

Tests cover:
- Basic functionality
- Race condition scenarios
- Label handling
- Prometheus format generation
- Error conditions

## Troubleshooting

### Common Issues

1. **Metrics not appearing**: Ensure metrics are registered before observation
2. **Memory issues**: Monitor shared dictionary size and label cardinality
3. **Race conditions**: Verify all label combinations are pre-registered

### Debug Information
```lua
-- Get current metrics summary
local summary = metrics:get_summary()
for key, value in pairs(summary) do
    print(key, value)
end
```
