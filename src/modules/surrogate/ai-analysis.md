# Surrogate Key Middleware - AI Analysis Document

## Purpose and Motivation

### Problem Statement
The current caching system in Sembo CDN only supports individual cache entry invalidation by specific cache keys. In real-world scenarios, applications often need to invalidate multiple related cache entries simultaneously. For example:

- When a hotel's information is updated, all cached responses related to that hotel should be invalidated
- When a user's preferences change, all cached responses containing user-specific data should be cleared
- When pricing information updates, all cached search results should be refreshed

### Surrogate Keys Solution
Surrogate keys (also known as cache tags) provide a mechanism to group multiple cache entries under logical tags, enabling bulk invalidation. This middleware implements the industry-standard approach used by CDNs like Fastly, Cloudflare, and Varnish.

## Technical Implementation Strategy

### Middleware Architecture Decision
**Decision**: Implement as a separate middleware rather than extending CacheMiddleware
**Rationale**:
1. **Single Responsibility**: Cache middleware handles HTTP Cache-Control compliance; surrogate middleware handles tag-based invalidation
2. **Optional Feature**: Not all deployments need surrogate key functionality
3. **Composability**: Can be enabled/disabled independently in the middleware chain
4. **Testing**: Easier to test tag functionality in isolation
5. **Maintenance**: Clear separation of concerns for easier debugging and feature development

### Middleware Chain Position
The SurrogateKeyMiddleware should be positioned **after** the CacheMiddleware in the processing chain:

```
Request → RouterMiddleware → CacheMiddleware → SurrogateKeyMiddleware → Upstream
```

This order ensures:
- Route patterns are available for tag generation
- Cache operations complete before tag operations
- Tags can be applied to responses that were cached
- Minimal performance impact on cache hits

### Data Model Design

#### Tag-to-Keys Mapping
```
Tag: "hotel:luxury-resort"
├── cache:GET:example.com:/hotel/luxury-resort
├── cache:GET:example.com:/hotel/luxury-resort/rooms
└── cache:GET:example.com:/hotel/luxury-resort/amenities
```

#### Key-to-Tags Mapping
```
Key: "cache:GET:example.com:/hotel/luxury-resort"
├── hotel:luxury-resort
├── hotels:all
└── content:hotel-data
```

### Redis Storage Strategy

#### Tag Sets (SADD/SMEMBERS)
- **Key Pattern**: `surrogate:tag:{tag_name}`
- **Value**: Set of cache keys
- **Purpose**: Efficient tag-based invalidation
- **TTL**: Slightly longer than cache entries to handle cleanup

#### Key Metadata (HSET/HGET)
- **Key Pattern**: `surrogate:key:{cache_key}`
- **Value**: Hash of metadata (tags, timestamp, route)
- **Purpose**: Reverse lookup and cleanup operations
- **TTL**: Same as cache entry TTL

## Feature Specifications

### Core Functionality
1. **Tag Assignment**: Automatic tag generation based on response headers and route patterns
2. **Tag Storage**: Efficient Redis-based tag-to-keys and keys-to-tags mapping
3. **Bulk Invalidation**: Single API call to invalidate all entries for a tag
4. **Cleanup**: Automatic removal of stale tag mappings
5. **Metrics**: Tag usage and invalidation metrics for monitoring

### Tag Generation Sources
1. **Response Headers**: `Surrogate-Key` or `Cache-Tags` headers from backend
2. **Route Patterns**: Automatic tags based on detected route patterns
3. **Configuration**: Static tag rules based on URL patterns
4. **Manual**: Explicit tag assignment via custom headers

### API Interface
- **Invalidation Endpoint**: `DELETE /cache/tags/{tag_name}`
- **Tag Listing**: `GET /cache/tags` (admin endpoint)
- **Tag Contents**: `GET /cache/tags/{tag_name}` (debug endpoint)

## Performance Considerations

### Optimization Strategies
1. **Lazy Tag Operations**: Tag assignments happen asynchronously after response
2. **Batch Operations**: Group multiple tag operations into single Redis pipeline
3. **TTL Management**: Automatic cleanup of expired tag mappings
4. **Memory Efficiency**: Use Redis data structures optimized for set operations

### Monitoring Points
- Tag assignment latency
- Invalidation operation time
- Tag storage memory usage
- Orphaned tag cleanup frequency

## Integration with Existing System

### Compatibility
- **Zero Breaking Changes**: Existing cache behavior remains unchanged
- **Backward Compatible**: Can be deployed without affecting current functionality
- **Gradual Adoption**: Tags can be enabled per-route or per-response basis

### Configuration
- **Environment Variables**: Enable/disable surrogate key functionality
- **Route Patterns**: Extend existing route pattern config with tag rules
- **Redis Integration**: Uses existing Redis connection pooling

## Implementation Phases

### Phase 1: Basic Infrastructure ✅
- [x] Middleware skeleton with cache provider integration
- [x] Unit test framework
- [x] Documentation and analysis

### Phase 2: Tag Assignment (Next)
- [ ] Response header parsing for surrogate keys
- [ ] Automatic tag generation from route patterns
- [ ] Redis tag storage implementation
- [ ] Integration tests

### Phase 3: Invalidation API
- [ ] HTTP endpoints for tag invalidation
- [ ] Bulk invalidation operations
- [ ] Admin endpoints for tag management
- [ ] Security and rate limiting

### Phase 4: Advanced Features
- [ ] Tag metrics and monitoring
- [ ] Automatic cleanup and maintenance
- [ ] Performance optimizations
- [ ] Advanced tag generation rules

## Usage Examples

### Automatic Tags from Route Patterns
```
Request: GET /hotel/luxury-resort
Route Pattern: hotel/[name]
Generated Tags: ["hotel:luxury-resort", "hotels:all", "content:hotel"]
```

### Backend-Provided Tags
```
Backend Response Headers:
Surrogate-Key: hotel:luxury-resort pricing:2024 availability:current

Generated Tags: ["hotel:luxury-resort", "pricing:2024", "availability:current"]
```

### Invalidation Operations
```bash
# Invalidate all hotel-related cache entries
curl -X DELETE http://cdn.example.com/cache/tags/hotel:luxury-resort

# Invalidate all pricing data
curl -X DELETE http://cdn.example.com/cache/tags/pricing:2024
```

## Benefits

### For Developers
- **Simplified Cache Management**: No need to track individual cache keys
- **Logical Grouping**: Cache invalidation aligned with business logic
- **Debugging**: Easy to see what cache entries are related

### For Operations
- **Efficient Invalidation**: Single operation can clear thousands of cache entries
- **Reduced Backend Load**: More targeted cache clearing reduces unnecessary cache misses
- **Monitoring**: Better visibility into cache usage patterns

### For Performance
- **Selective Invalidation**: Only invalidate what actually changed
- **Cache Warmth**: Preserve unrelated cache entries during updates
- **Reduced Latency**: Faster cache invalidation operations
