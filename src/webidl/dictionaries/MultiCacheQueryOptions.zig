//! WebIDL dictionary: MultiCacheQueryOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const CacheQueryOptions = @import("CacheQueryOptions.zig").CacheQueryOptions;

pub const MultiCacheQueryOptions = struct {
    // Inherited from CacheQueryOptions
    base: CacheQueryOptions,

    cacheName: ?runtime.DOMString = null,
};
