# Surrogate Key Middleware

A tag-based cache invalidation system for bulk cache management and logical grouping of cache entries.

## Overview

The Surrogate Key Middleware implements industry-standard cache tagging (surrogate keys) to enable bulk invalidation of related cache entries. This solves the common problem of needing to invalidate multiple cache entries when underlying data changes.

## Problem Solved

**Before**: Individual cache key invalidation only
```bash
# Need to invalidate each key individually
curl -X DELETE /cache/key/cache:GET:example.com:/hotel/luxury-resort
curl -X DELETE /cache/key/cache:GET:example.com:/hotel/luxury-resort/rooms
curl -X DELETE /cache/key/cache:GET:example.com:/hotel/luxury-resort/amenities
```

**After**: Tag-based bulk invalidation
```bash
# Single operation invalidates all related entries
curl -X DELETE /cache/tags/hotel:luxury-resort
```

## Features

- **Automatic Tag Generation**: Tags created from response headers and route patterns
- **Bulk Invalidation**: Single API call to clear multiple cache entries
- **Redis Integration**: Efficient storage using Redis sets and hashes
- **Zero Breaking Changes**: Works alongside existing cache middleware
- **Performance Optimized**: Asynchronous tag operations with connection pooling

## Architecture

### Middleware Position
```
Request Flow:
Router → Cache → Surrogate → Upstream
       ↓       ↓        ↓
    Pattern  Cache   Tag Assignment
   Detection Hit/Miss  & Storage
```

### Data Model
```
Tags → Cache Keys Mapping:
surrogate:tag:hotel:luxury-resort → {
  "cache:GET:example.com:/hotel/luxury-resort",
  "cache:GET:example.com:/hotel/luxury-resort/rooms"
}

Cache Key → Tags Mapping:
surrogate:key:cache:GET:example.com:/hotel/luxury-resort → {
  "tags": ["hotel:luxury-resort", "hotels:all"],
  "timestamp": 1640995200,
  "route": "hotel/[name]"
}
```

## Usage

### Automatic Tag Generation

Tags are automatically generated from:

1. **Route Patterns**
```
Route: hotel/[name] + Request: /hotel/luxury-resort
→ Tags: ["hotel:luxury-resort", "hotels:all"]
```

2. **Response Headers**
```
Backend Response:
Surrogate-Key: hotel:luxury-resort pricing:2024 availability:current
→ Tags: ["hotel:luxury-resort", "pricing:2024", "availability:current"]
```

### Invalidation API

```bash
# Invalidate all entries for a specific hotel
curl -X DELETE http://localhost:8080/cache/tags/hotel:luxury-resort

# Invalidate all pricing data
curl -X DELETE http://localhost:8080/cache/tags/pricing:2024

# List all tags (admin)
curl http://localhost:8080/cache/tags

# View tag contents (debug)
curl http://localhost:8080/cache/tags/hotel:luxury-resort
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SURROGATE_ENABLED` | `false` | Enable surrogate key functionality |
| `SURROGATE_TAG_TTL` | `3600` | TTL for tag mappings (seconds) |
| `SURROGATE_MAX_TAGS` | `10` | Maximum tags per cache entry |
| `SURROGATE_AUTO_TAGS` | `true` | Auto-generate tags from route patterns |

### Route Pattern Tags

Extend existing route patterns with tag configuration:

```json
{
  "patterns": [
    {
      "regex": "^/hotel/([^/]+)$",
      "name": "hotel/[name]",
      "tags": ["hotel:{1}", "hotels:all", "content:hotel"]
    },
    {
      "regex": "^/api/v(\\d+)/search",
      "name": "api/v[version]/search",
      "tags": ["search:all", "api:v{1}"]
    }
  ]
}
```

## Implementation Status

### Current Phase: Basic Infrastructure ✅
- [x] Middleware skeleton with provider integration
- [x] Unit test framework
- [x] Documentation and architecture design

### Next Phase: Tag Assignment
- [ ] Response header parsing (`Surrogate-Key`, `Cache-Tags`)
- [ ] Route pattern tag generation
- [ ] Redis storage operations
- [ ] Tag assignment during cache operations

### Future Phases
- [ ] HTTP invalidation endpoints
- [ ] Admin and debug interfaces
- [ ] Advanced tag rules and configuration
- [ ] Performance metrics and monitoring

## Examples

### Hotel Content Management
```
# Backend updates hotel information
PUT /admin/hotels/luxury-resort

# CDN invalidates all related cache entries
POST /cache/invalidate
{
  "tags": ["hotel:luxury-resort"]
}

# Clears:
# - /hotel/luxury-resort (hotel details)
# - /hotel/luxury-resort/rooms (room listings)
# - /hotel/luxury-resort/amenities (amenities)
# - /search?location=beach (if hotel appears in search)
```

### Pricing Updates
```
# Pricing system updates rates
PUT /admin/pricing/2024

# CDN invalidates all pricing-related content
POST /cache/invalidate
{
  "tags": ["pricing:2024"]
}

# Clears all cached responses containing 2024 pricing data
```

### User-Specific Content
```
# User preferences change
PUT /users/123/preferences

# CDN invalidates user-specific cached content
POST /cache/invalidate
{
  "tags": ["user:123"]
}

# Clears personalized search results, recommendations, etc.
```

## Benefits

### Operational Efficiency
- **Selective Invalidation**: Only clear what actually changed
- **Bulk Operations**: Single command for complex invalidation scenarios
- **Reduced Backend Load**: Avoid unnecessary cache misses

### Developer Experience
- **Logical Grouping**: Cache management aligned with business logic
- **Simplified Integration**: Automatic tag generation from existing patterns
- **Debugging Support**: Clear visibility into tag relationships

### Performance Impact
- **Minimal Overhead**: Asynchronous tag operations
- **Efficient Storage**: Optimized Redis data structures
- **Fast Invalidation**: Set-based operations for bulk clearing

## Testing

### Unit Tests
```bash
# Run surrogate middleware tests
busted tests/unit/modules/surrogate/ --verbose
```

### Integration Tests
```bash
# Test with Redis (when implemented)
busted tests/integration/modules/surrogate/ --verbose
```

### Manual Testing
```bash
# Test tag generation (development)
curl -v http://localhost:8080/hotel/luxury-resort

# Check assigned tags (when admin endpoints exist)
curl http://localhost:8080/cache/tags
```

## Monitoring

### Metrics (Planned)
- `surrogate_tags_assigned_total`: Total tags assigned
- `surrogate_invalidations_total`: Tag invalidation operations
- `surrogate_tag_storage_bytes`: Memory usage for tag mappings
- `surrogate_orphaned_tags_cleaned`: Automatic cleanup operations

### Health Checks
Tag functionality will be included in the existing health check endpoint:

```json
{
  "services": {
    "surrogate": {
      "status": "healthy",
      "tags_stored": 1234,
      "last_cleanup": "2024-01-01T12:00:00Z"
    }
  }
}
```
