# Surrogate Key Middleware

A tag-based cache invalidation system enabling bulk cache management through logical grouping of cache entries.

## Problem & Solution

**Problem**: Traditional caching only supports individual cache key invalidation, making it difficult to invalidate related cache entries when underlying data changes.

**Solution**: Surrogate keys (cache tags) allow grouping multiple cache entries under logical tags for bulk invalidation.

### Before vs After

**Before**: Individual invalidation
```bash
curl -X DELETE /cache/key/cache:GET:example.com:/hotel/luxury-resort
curl -X DELETE /cache/key/cache:GET:example.com:/hotel/luxury-resort/rooms
curl -X DELETE /cache/key/cache:GET:example.com:/hotel/luxury-resort/amenities
```

**After**: Tag-based bulk invalidation
```bash
curl -X DELETE /cache/tags/hotel:luxury-resort
```

## Key Features

- **Automatic Tag Processing**: Extracts tags from response `Surrogate-Key` headers
- **Bulk Invalidation**: Single API call clears multiple related cache entries
- **Redis Integration**: Efficient storage using Redis sets and hash tables
- **Zero Breaking Changes**: Works alongside existing cache middleware
- **Performance Optimized**: Asynchronous operations with connection pooling

For detailed technical analysis, see [ai-analysis.md](ai-analysis.md).

## Architecture

### Middleware Integration
```
Request → Cache → Router → Surrogate → Upstream → Response
```

The surrogate middleware processes responses after caching to associate cache keys with tags.

### Data Model
```
Redis Tag Storage:
surrogate:tag:hotel:luxury-resort → {
  "cache:GET:example.com:/hotel/luxury-resort",
  "cache:GET:example.com:/hotel/luxury-resort/rooms",
  "cache:GET:example.com:/hotel/luxury-resort/amenities"
}

Redis Key-to-Tags Mapping:
cache:GET:example.com:/hotel/luxury-resort → {
  "hotel:luxury-resort",
  "pricing:2024-01",
  "availability:current"
}
```

## Usage

### Automatic Tag Processing
The middleware automatically processes `Surrogate-Key` headers in responses:

```lua
-- Backend response includes surrogate keys
response.headers["Surrogate-Key"] = "hotel:luxury-resort pricing:2024-01"
-- Middleware automatically associates cache key with these tags
```

### Bulk Invalidation API
```bash
# Invalidate all entries tagged with hotel:luxury-resort
curl -X DELETE /cache/tags/hotel:luxury-resort

# Response indicates number of entries invalidated
# "Invalidated 15 cache entries for tag 'hotel:luxury-resort'"
```

### Tag Naming Conventions
```
Entity-based tags:
- hotel:luxury-resort
- user:12345
- category:electronics

Time-based tags:
- pricing:2024-01
- availability:current
- promotion:summer-sale

Feature-based tags:
- search-results
- user-preferences
- recommendations
```

## Implementation

### Middleware Setup
The middleware is automatically configured in the main pipeline:

```lua
-- handlers/main/surrogate.lua
local SurrogateKeyMiddleware = require "modules.surrogate.middleware"
local tags_provider = require "handlers.utils.tags_provider"
local cache_key_strategy = require "modules.cache.key_strategy_host_path"

return SurrogateKeyMiddleware:new(tags_provider, cache_key_strategy)
```

### Backend Integration
Backends should include `Surrogate-Key` headers in responses:

```http
HTTP/1.1 200 OK
Content-Type: application/json
Cache-Control: public, max-age=3600
Surrogate-Key: hotel:luxury-resort pricing:2024-01 availability:current

{"name": "Luxury Resort", "price": 299, "available": true}
```

### Manual Tag Operations
```lua
-- Get all cache keys for a tag
local keys = tags_provider:get_keys_for_tag("hotel:luxury-resort")

-- Add cache key to tag
tags_provider:add_key_to_tag("cache:GET:example.com:/hotel/new-hotel", "hotel:new-hotel")

-- Remove cache key from tag
tags_provider:remove_key_from_tag("hotel:old-hotel", "cache:GET:example.com:/hotel/old-hotel")

-- Delete entire tag and all associations
tags_provider:del_by_tag("hotel:closed-hotel")
```

## Performance Characteristics

### Tag Operations
- **Tag Assignment**: O(1) per tag per cache key
- **Bulk Invalidation**: O(n) where n = number of tagged cache keys
- **Memory Usage**: ~100 bytes per tag-key association

### Redis Operations
- **Tag Storage**: Redis sets for efficient membership operations
- **Key Lookup**: Hash tables for reverse mapping
- **Connection Pooling**: Shared Redis connections across operations

## Best Practices

### 1. Hierarchical Tag Structure
```
-- Good: Hierarchical organization
hotel:luxury-resort
hotel:luxury-resort:rooms
hotel:luxury-resort:amenities

-- Bad: Flat structure
luxury-resort
luxury-resort-rooms
luxury-resort-amenities
```

### 2. Reasonable Tag Cardinality
```
-- Good: Limited, predictable tags
hotel:*, category:*, region:*

-- Bad: High cardinality tags
user:*, session:*, request:*
```

### 3. Consistent Tag Naming
```
-- Good: Consistent naming convention
entity:identifier
feature:state
time:period

-- Bad: Inconsistent naming
HotelLuxuryResort
hotel_luxury_resort
hotel-luxury-resort
```

### 4. Strategic Tag Usage
```
-- Tag for business logic changes
Surrogate-Key: hotel:luxury-resort pricing:2024-01

-- Don't tag for request-specific data
Surrogate-Key: user:12345 session:abc123  # Too granular
```

## Troubleshooting

### Common Issues

**Tags Not Working**
- Check `Surrogate-Key` header format in backend responses
- Verify Redis connectivity: `curl http://localhost:8080/health`
- Ensure tags don't contain spaces or special characters

**Invalidation Not Working**
- Verify tag exists: check Redis for `surrogate:tag:your-tag`
- Test invalidation endpoint: `curl -X DELETE /cache/tags/your-tag`
- Check logs for Redis connection errors

**Performance Issues**
- Monitor tag cardinality to avoid too many keys per tag
- Use Redis clustering for high-volume tag operations
- Consider async invalidation for large tag sets

### Debug Information
```bash
# Check tag associations in Redis
redis-cli SMEMBERS surrogate:tag:hotel:luxury-resort

# Check tags for a specific cache key
redis-cli HGET surrogate:key:cache:GET:example.com:/hotel/luxury-resort tags

# Monitor tag operations
curl http://localhost:8080/metrics | grep tag_operation
```

For detailed implementation analysis, see [ai-analysis.md](ai-analysis.md).
