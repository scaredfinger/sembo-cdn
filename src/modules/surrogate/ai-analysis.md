# Surrogate Keys Technical Analysis

## Design Rationale

### Problem Context
Traditional reverse proxy caching systems only support individual cache key invalidation. In real-world applications, data changes often require invalidating multiple related cache entries simultaneously.

**Example Scenario**: When a hotel's pricing changes, all cached responses containing that hotel's information should be invalidated:
- `/hotel/luxury-resort` (hotel details)
- `/hotel/luxury-resort/rooms` (room listings)  
- `/search?location=beach` (search results containing the hotel)
- `/recommendations?user=123` (personalized recommendations)

### Solution: Surrogate Keys (Cache Tags)
Surrogate keys allow associating multiple cache entries with logical tags, enabling bulk invalidation through a single operation.

## Technical Implementation

### Architecture Decision: Separate Middleware
**Decision**: Implement as dedicated middleware rather than extending CacheMiddleware

**Rationale**:
- **Single Responsibility**: Cache handles HTTP compliance; surrogate handles tag management
- **Optional Feature**: Can be disabled for deployments that don't need tag-based invalidation
- **Composability**: Integrates cleanly into existing middleware pipeline
- **Testing**: Easier to test tag functionality in isolation
- **Performance**: Minimal impact on cache operations when tags aren't used

### Middleware Chain Position
```
Request → Cache → Router → Surrogate → Metrics → Upstream
```

Positioning after CacheMiddleware ensures:
- Cache operations complete before tag processing
- Tags are applied to responses that were actually cached
- No performance impact on cache hits (tags processed after response)
- Route information available for automatic tag generation

## Data Model Design

### Redis Storage Strategy

#### Tag-to-Keys Mapping (Redis Sets)
```
Key: surrogate:tag:hotel:luxury-resort
Value: {"cache:GET:example.com:/hotel/luxury-resort", "cache:GET:example.com:/hotel/luxury-resort/rooms"}
```

#### Key-to-Tags Mapping (Redis Hash)
```
Key: surrogate:key:cache:GET:example.com:/hotel/luxury-resort
Value: {"hotel:luxury-resort", "pricing:2024-01", "availability:current"}
```

### Benefits of Dual Mapping
- **Fast Invalidation**: O(1) lookup of all keys for a tag
- **Efficient Cleanup**: O(1) lookup of all tags for a key during cache expiration
- **Atomic Operations**: Redis sets provide atomic membership operations
- **Memory Efficient**: Shared string storage in Redis

## Implementation Components

### Core Middleware
```lua
-- modules/surrogate/middleware.lua
-- Processes Surrogate-Key headers in responses
-- Associates cache keys with extracted tags
-- Integrates with existing cache key strategy
```

### Tag Management
```lua
-- modules/surrogate/surrogate_key_parser.lua
-- Parses Surrogate-Key headers (space-separated tags)
-- Validates tag format and structure
-- Handles multiple tags per response
```

### Invalidation Handler
```lua
-- modules/surrogate/invalidate_tag_handler.lua
-- REST API for bulk cache invalidation
-- Handles DELETE /cache/tags/{tag} requests
-- Coordinates cache deletion across all tagged keys
```

### Redis Provider
```lua
-- modules/surrogate/providers/redis_tags_provider.lua
-- Manages Redis storage operations
-- Handles connection pooling and error recovery
-- Provides atomic tag assignment and removal
```

## Performance Characteristics

### Tag Assignment
- **Time Complexity**: O(n) where n = number of tags per response
- **Memory Overhead**: ~100 bytes per tag-key association
- **Redis Operations**: 2 operations per tag (set membership + hash update)

### Bulk Invalidation
- **Time Complexity**: O(m) where m = number of cache keys with the tag
- **Cache Deletion**: Parallel deletion of all tagged cache entries
- **Redis Operations**: 1 set lookup + m cache deletions + cleanup

### Memory Usage
- **Tag Storage**: ~50 bytes per tag name
- **Key Associations**: ~150 bytes per key-tag pair
- **Total Overhead**: ~5-10% of total cache size for typical tag usage

## Integration Points

### Automatic Tag Detection
The middleware automatically processes `Surrogate-Key` headers:

```http
HTTP/1.1 200 OK
Surrogate-Key: hotel:luxury-resort pricing:2024-01
Cache-Control: public, max-age=3600
```

### Cache Key Strategy Integration
Uses existing cache key generation strategy for consistency:

```lua
-- Same strategy as CacheMiddleware
local cache_key = cache_key_strategy(request) -- "cache:GET:example.com:/hotel/luxury-resort"
```

### Metrics Integration
Tag operations are tracked in the metrics system:

```lua
-- Success/failure metrics for tag operations
metrics:observe_composite_success("tag_operation", duration, {operation="assign"})
metrics:inc_composite_failure("tag_operation", 1, {operation="invalidate"})
```

## Error Handling & Reliability

### Graceful Degradation
- **Redis Unavailable**: Tags are skipped, cache continues normal operation
- **Tag Format Errors**: Invalid tags are logged and ignored
- **Partial Failures**: Failed tag assignments don't block response processing

### Consistency Guarantees
- **Cache-Tag Consistency**: Tags are only assigned after successful cache storage
- **Atomic Operations**: Redis operations use transactions for consistency
- **Cleanup Handling**: Orphaned tags are cleaned up during cache expiration

## Security Considerations

### Tag Validation
- **Format Validation**: Tags must match `^[a-zA-Z0-9:_-]+$` pattern
- **Length Limits**: Maximum 64 characters per tag, 20 tags per response
- **Injection Prevention**: Tags are sanitized before Redis operations

### Access Control
- **Management Endpoints**: Invalidation API should be protected in production
- **Tag Enumeration**: No public API for listing available tags
- **Rate Limiting**: Bulk invalidation operations should be rate-limited

## Testing Strategy

### Unit Tests
- **Tag Parser**: Various header formats, edge cases, malformed input
- **Middleware**: Integration with cache key strategy, error handling
- **Handler**: REST API responses, error conditions
- **Provider**: Redis operations, connection failures

### Integration Tests
- **End-to-End**: Full request processing with tag assignment
- **Bulk Invalidation**: Verify all tagged entries are cleared
- **Performance**: Tag operations under load

### Property-Based Testing
- **Tag Consistency**: Verify tag-key mappings remain consistent
- **Idempotency**: Multiple tag assignments/removals are idempotent
- **Cleanup**: Orphaned tags are properly cleaned up

## Future Enhancements

### Planned Features
- **Tag Hierarchies**: Support for nested tag relationships (hotel:luxury-resort:rooms)
- **Tag Expiration**: Automatic cleanup of unused tags after TTL
- **Batch Operations**: Bulk tag assignment and invalidation APIs
- **Tag Analytics**: Statistics on tag usage patterns and effectiveness

### Performance Optimizations
- **Connection Pooling**: Dedicated Redis connections for tag operations
- **Batch Processing**: Group multiple tag operations into single Redis call
- **Compression**: Compress tag storage for memory efficiency
- **Sharding**: Distribute tags across multiple Redis instances

### Operational Features
- **Admin Interface**: Web UI for tag management and debugging
- **Monitoring**: Detailed metrics on tag performance and usage
- **Alerting**: Notifications for tag-related issues or anomalies
- **Debugging**: Enhanced logging and tracing for tag operations

This implementation provides a solid foundation for tag-based cache invalidation while maintaining the system's performance characteristics and reliability guarantees.
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
