# Metrics Module

A thread-safe Prometheus metrics module for OpenResty/nginx environments, supporting both histogram and counter metrics with race condition protection.

## Features

- **Thread-Safe**: Uses atomic operations to prevent race conditions in multi-worker environments
- **Histogram & Counter Support**: Specialized for both histogram and counter metrics
- **Label Support**: Full support for metric labels with automatic key generation
- **Prometheus Compatible**: Generates standard Prometheus exposition format
- **Memory Efficient**: Pre-initializes metrics to avoid runtime allocation issues
- **Composite Metrics**: Register success and failure metrics together for convenience

## Quick Start

```lua
local Metrics = require "modules.metrics.index"

-- Initialize with OpenResty shared dictionary
local metrics = Metrics.new(ngx.shared.metrics)

-- Register composite metrics for common success/failure patterns
metrics:register_composite(
    "upstream_request",
    "Upstream request metrics",
    {
        method={"GET", "POST", "PUT"},
        route={"/api/users", "/api/orders", "/health"},
        cache_state={"hit", "miss", "stale"}
    }
)

-- Register individual metrics
metrics:register_counter(
    "http_requests_total",
    "Total HTTP requests",
    {
        method={"GET", "POST", "PUT"},
        route={"/api/users", "/api/orders", "/health"}
    }
)

-- Register a histogram with expected label combinations
metrics:register_histogram(
    "response_time_seconds",
    "HTTP response time in seconds",
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

-- Record metrics
metrics:observe_composite_success("upstream_request", 0.125, {
    method="GET", 
    route="/api/users",
    cache_state="hit"
})

metrics:inc_composite_failure("upstream_request", 1, {
    method="POST", 
    route="/api/orders",
    cache_state="miss"
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

#### `metrics:register_counter(name, help, label_values)`
Registers a counter metric with pre-defined label combinations.

**Parameters:**
- `name` (string): Metric name
- `help` (string): Help text for Prometheus
- `label_values` (optional): Table mapping label names to arrays of possible values

**Example:**
```lua
metrics:register_counter(
    "http_requests_total",
    "Total HTTP requests",
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

#### `metrics:register_histogram(name, help, label_values, buckets)`
Registers a histogram metric with pre-defined label combinations.

**Parameters:**
- `name` (string): Metric name
- `help` (string): Help text for Prometheus
- `label_values` (optional): Table mapping label names to arrays of possible values
- `buckets` (optional): Array of bucket boundaries

**Example:**
```lua
metrics:register_histogram(
    "request_duration",
    "Request duration in seconds",
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

### Composite Methods

Composite metrics allow you to register both a success histogram and failure counter with the same labels in a single call. This is particularly useful for tracking operation success/failure patterns.

#### `metrics:register_composite(config)`
Registers both a success histogram and failure counter with shared labels using a strongly typed configuration object.

**Parameters:**
- `config` (CompositeMetricConfig): Configuration object with the following fields:
  - `name` (string): Base metric name (will be prefixed with "success_"/"failed_")
  - `help` (string): Help text for both metrics
  - `label_values` (optional): Table mapping label names to arrays of possible values
  - `histogram_suffix` (optional, default="_seconds"): Suffix for the histogram metric
  - `counter_suffix` (optional, default="_total"): Suffix for the counter metric  
  - `buckets` (optional): Array of histogram bucket boundaries

**Example:**
```lua
metrics:register_composite({
    name = "api_request",
    help = "API request metrics",
    label_values = {
        method = {"GET", "POST"},
        status = {"200", "404", "500"}
    },
    histogram_suffix = "_duration_seconds",    -- Creates: success_api_request_duration_seconds
    counter_suffix = "_failures"               -- Creates: failed_api_request_failures
})
```

#### `metrics:observe_composite_success(base_name, value, labels)`
Records a successful operation for the composite metric.

**Parameters:**
- `base_name` (string): Base metric name used in registration
- `value` (number): Observed value for the histogram
- `labels` (optional): Table of label key-value pairs

**Example:**
```lua
metrics:observe_composite_success("api_request", 0.125, {
    method="GET", 
    status="200"
})
```

#### `metrics:inc_composite_failure(base_name, value, labels)`
Records a failed operation for the composite metric.

**Parameters:**
- `base_name` (string): Base metric name used in registration
- `value` (optional, default=1): Increment value for the counter
- `labels` (optional): Table of label key-value pairs

**Example:**
```lua
metrics:inc_composite_failure("api_request", 1, {
    method="POST", 
    status="500"
})
```

### `metrics:generate_prometheus()`
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
    {endpoint={"/users", "/orders"}})
    
metrics:register_histogram("api_response_time", "API response time", 
    {endpoint={"/users", "/api/orders"}})
```

### 2. Pre-define Label Combinations
```lua
-- Define expected label combinations to avoid runtime allocation
local endpoints = {"/api/users", "/api/orders", "/health"}
local methods = {"GET", "POST", "PUT", "DELETE"}

metrics:register_counter("request_count", "Request count", 
    {method=methods, endpoint=endpoints})
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

### 4. Use Composite Metrics for Success/Failure Patterns
```lua
-- Register composite metrics for operations that can succeed or fail
metrics:register_composite("database_query", "Database query metrics", 
    {operation={"SELECT", "INSERT", "UPDATE"}, table={"users", "orders"}})
    
metrics:register_composite("cache_operation", "Cache operation metrics",
    {operation={"GET", "SET", "DELETE"}})

-- Record operations
metrics:observe_composite_success("database_query", 0.015, {operation="SELECT", table="users"})
metrics:inc_composite_failure("cache_operation", 1, {operation="GET"})
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

-- Register composite metrics during init
metrics:register_composite("api_request", "API request metrics", 
    {endpoint={"/api/users", "/api/orders"}, method={"GET", "POST"}})

-- Use in request handlers
local start_time = ngx.now()
local success, result = pcall(function()
    -- ... handle request ...
    return handle_api_request()
end)

local duration = ngx.now() - start_time
local labels = {endpoint="/api/users", method="GET"}

if success then
    metrics:observe_composite_success("api_request", duration, labels)
else
    metrics:inc_composite_failure("api_request", 1, labels)
end
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
