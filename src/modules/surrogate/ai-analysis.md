# Surrogate Keys Technical Analysis

## Overview

The Surrogate Keys module provides tag-based cache invalidation functionality for the OpenResty CDN system. It enables efficient bulk cache invalidation by associating multiple cache entries with logical tags.

## Problem Statement

Traditional reverse proxy caching systems only support individual cache key invalidation. In real-world applications, data changes often require invalidating multiple related cache entries simultaneously.

**Example Scenario**: When a hotel's pricing changes, all cached responses containing that hotel's information should be invalidated:
- `/hotel/luxury-resort` (hotel details)
- `/hotel/luxury-resort/rooms` (room listings)  
- `/search?location=beach` (search results containing the hotel)
- `/recommendations?user=123` (personalized recommendations)

## Solution: Surrogate Keys (Cache Tags)

Surrogate keys allow associating multiple cache entries with logical tags, enabling bulk invalidation through a single operation.

## Architecture Design

### Middleware Approach
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

## Data Model

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

### Core Middleware (`middleware.lua`)
- Processes `Surrogate-Key` headers in responses
- Associates cache keys with extracted tags
- Integrates with existing cache key strategy

### Tag Parser (`surrogate_key_parser.lua`)
- Parses `Surrogate-Key` headers (space-separated tags)
- Validates tag format and structure
- Handles multiple tags per response

### Invalidation Handler (`invalidate_tag_handler.lua`)
- REST API for bulk cache invalidation
- Handles `DELETE /cache/tags/{tag}` requests
- Coordinates cache deletion across all tagged keys

### Redis Provider (`providers/redis_tags_provider.lua`)
- Manages Redis storage operations
- Handles connection pooling and error recovery
- Provides atomic tag assignment and removal

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
metrics:observe_histogram_success("tag_operation", duration, {operation="assign"})
metrics:observe_histogram_failure("tag_operation", 1, {operation="invalidate"})
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

## API Interface

### Invalidation Endpoint
- **URL**: `DELETE /cache/tags/{tag_name}`
- **Purpose**: Invalidate all cache entries associated with a tag
- **Response**: Count of invalidated cache entries

### Tag Management (Admin)
- **Tag Listing**: `GET /cache/tags` (protected endpoint)
- **Tag Contents**: `GET /cache/tags/{tag_name}` (debug information)

## Usage Examples

### Backend-Provided Tags
```http
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

## Benefits

### Operational Benefits
- **Efficient Invalidation**: Single operation can clear thousands of cache entries
- **Reduced Backend Load**: More targeted cache clearing reduces unnecessary cache misses
- **Monitoring**: Better visibility into cache usage patterns

### Developer Benefits
- **Simplified Cache Management**: No need to track individual cache keys
- **Logical Grouping**: Cache invalidation aligned with business logic
- **Debugging**: Easy to see what cache entries are related

### Performance Benefits
- **Selective Invalidation**: Only invalidate what actually changed
- **Cache Warmth**: Preserve unrelated cache entries during updates
- **Reduced Latency**: Faster cache invalidation operations

This implementation provides a robust foundation for tag-based cache invalidation while maintaining the system's performance and reliability characteristics.
