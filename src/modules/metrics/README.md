# Metrics Module

A thread-safe Prometheus metrics collection module for OpenResty environments, designed for high-performance applications with race condition protection.

## Key Features

- **Thread-Safe**: Atomic operations prevent race conditions in multi-worker environments
- **Prometheus Compatible**: Standard exposition format with automatic type annotations
- **Flexible Labels**: Dynamic label combinations with pre-registration optimization
- **Composite Metrics**: Success/failure patterns with single registration
- **Memory Efficient**: Pre-initialization strategy avoids runtime allocation issues

## Quick Start

```lua
local Metrics = require "modules.metrics.index"
local metrics = Metrics.new(ngx.shared.metrics)

-- Register composite metrics for request tracking
metrics:register_composite({
    name = "api_request",
    help = "API request performance metrics",
    label_values = {
        method = {"GET", "POST", "PUT", "DELETE"},
        route = {"/users", "/orders", "/health"},
        status = {"200", "404", "500"}
    }
})

-- Record successful requests
metrics:observe_composite_success("api_request", 0.125, {
    method="GET", route="/users", status="200"
})

-- Record failed requests
metrics:inc_composite_failure("api_request", 1, {
    method="POST", route="/orders", status="500"
})

-- Generate Prometheus output
local prometheus_output = metrics:generate_prometheus()
```

For detailed technical analysis, see [ai-analysis.md](ai-analysis.md).

## Core API

### Initialization
```lua
local Metrics = require "modules.metrics.index"
local metrics = Metrics.new(ngx.shared.metrics)
```

### Registration Methods

#### Composite Metrics (Recommended)
Register both success histogram and failure counter with shared labels:

```lua
metrics:register_composite({
    name = "database_operation",
    help = "Database operation metrics",
    label_values = {
        operation = {"SELECT", "INSERT", "UPDATE"},
        table = {"users", "orders", "products"}
    },
    histogram_suffix = "_duration_seconds",
    counter_suffix = "_failures_total",
    buckets = {0.001, 0.01, 0.1, 1.0, 10.0}
})
```

#### Individual Metrics
```lua
-- Counter for simple counting
metrics:register_counter("cache_operations_total", {
    operation = {"GET", "SET", "DELETE"},
    status = {"hit", "miss", "error"}
})

-- Histogram for timing measurements
metrics:register_histogram("response_time_seconds", {
    endpoint = {"/api/users", "/api/orders"},
    method = {"GET", "POST"}
}, {0.1, 0.5, 1.0, 2.5, 5.0})
```

### Observation Methods

#### Composite Operations
```lua
-- Record successful operation
metrics:observe_composite_success("database_operation", 0.025, {
    operation="SELECT", table="users"
})

-- Record failed operation
metrics:inc_composite_failure("database_operation", 1, {
    operation="INSERT", table="orders"
})
```

#### Individual Metrics
```lua
-- Increment counter
metrics:inc_counter("cache_operations_total", 1, {
    operation="GET", status="hit"
})

-- Observe histogram value
metrics:observe_histogram("response_time_seconds", 0.125, {
    endpoint="/api/users", method="GET"
})
```

### Output Generation
```lua
-- Prometheus exposition format
local prometheus_text = metrics:generate_prometheus()

-- Debug summary
local summary = metrics:get_summary()
```

## Configuration

Add to your nginx configuration:
```nginx
lua_shared_dict metrics 10m;
```

## Architecture

### Thread Safety
- **Pre-initialization**: All metric keys created during registration
- **Atomic Operations**: Only `ngx.shared.dict:incr()` used for observations
- **No Check-Then-Set**: Eliminates race condition windows

### Memory Management
- **Shared Dictionary**: Efficient storage in nginx shared memory
- **Label Serialization**: Consistent key generation from label combinations
- **Garbage Collection**: Automatic cleanup of unused metrics

### Performance
- **O(1) Observations**: Constant time metric updates
- **O(n) Key Building**: Linear with number of labels
- **Optimized Buckets**: Default histogram buckets for common use cases

## Best Practices

### 1. Pre-register Label Combinations
```lua
-- Define expected values during initialization
local methods = {"GET", "POST", "PUT", "DELETE"}
local routes = {"/api/users", "/api/orders", "/health"}

metrics:register_counter("requests_total", {
    method = methods,
    route = routes
})
```

### 2. Use Composite Metrics for Success/Failure Patterns
```lua
-- Single registration for both success and failure tracking
metrics:register_composite({
    name = "api_operation",
    label_values = {
        operation = {"user_create", "order_process", "payment_charge"}
    }
})
```

### 3. Monitor Label Cardinality
```lua
-- Good: Limited combinations (3 × 4 = 12 metrics)
{method = {"GET", "POST", "PUT"}, status = {"200", "404", "500", "503"}}

-- Bad: High cardinality (avoid user IDs, timestamps, etc.)
{method = methods, user_id = user_ids} -- Potentially thousands of metrics
```

### 4. Use Descriptive Names
```lua
-- Good: Clear, consistent naming
metrics:register_histogram("http_request_duration_seconds", labels)
metrics:register_counter("http_requests_total", labels)

-- Bad: Ambiguous names
metrics:register_histogram("time", labels)
metrics:register_counter("count", labels)
```

## Integration Examples

### HTTP Handler
```lua
-- handlers/metrics/index.lua
local metrics = require "handlers.metrics.instance"
ngx.header["Content-Type"] = "text/plain; version=0.0.4; charset=utf-8"
ngx.say(metrics:generate_prometheus())
```

### Middleware Integration
```lua
-- Metrics middleware for request tracking
local function create_metrics_middleware(metrics, metric_name)
    return function(request, next)
        local start_time = ngx.now()
        local success, response = pcall(next, request)
        local duration = ngx.now() - start_time
        
        local labels = {
            method = request.method,
            route = response.locals.route or "unknown"
        }
        
        if success and response.status < 400 then
            metrics:observe_composite_success(metric_name, duration, labels)
        else
            metrics:inc_composite_failure(metric_name, 1, labels)
        end
        
        return response
    end
end
```

## Troubleshooting

### Common Issues

**Metrics Not Appearing**
- Verify metrics are registered before first observation
- Check shared dictionary size: `ngx.shared.metrics:capacity()`
- Ensure label combinations match registration

**Memory Issues**
- Monitor shared dictionary usage: `ngx.shared.metrics:free_space()`
- Reduce label cardinality
- Consider metric cleanup strategies

**Performance Problems**
- Pre-register all label combinations
- Avoid high-cardinality labels
- Use composite metrics for related operations

### Debug Information
```lua
-- Check current metrics
local summary = metrics:get_summary()
for key, value in pairs(summary) do
    ngx.log(ngx.INFO, "Metric: " .. key .. " = " .. value)
end

-- Monitor shared dictionary
local capacity = ngx.shared.metrics:capacity()
local free_space = ngx.shared.metrics:free_space()
ngx.log(ngx.INFO, "Metrics memory: " .. (capacity - free_space) .. "/" .. capacity)
```

For detailed implementation analysis, see [ai-analysis.md](ai-analysis.md).
