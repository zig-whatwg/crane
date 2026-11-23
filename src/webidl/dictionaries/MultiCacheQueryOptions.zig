//! WebIDL dictionary: MultiCacheQueryOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const CacheQueryOptions = @import("CacheQueryOptions.zig").CacheQueryOptions;

pub const MultiCacheQueryOptions = struct {
    /// A WebIDL dictionary (the binding's dictionary rules read this marker).
    pub const webidl_dictionary = true;
    // Inherited from CacheQueryOptions
    base: CacheQueryOptions,

    cacheName: ?runtime.DOMString = null,
};
