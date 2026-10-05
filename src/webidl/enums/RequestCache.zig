//! WebIDL enum: RequestCache
//!
//! This file is AUTO-GENERATED. Do not edit manually.

pub const RequestCache = enum {
    _default_,
    _no_store_,
    _reload_,
    _no_cache_,
    _force_cache_,
    _only_if_cached_,

    /// Each variant's value exactly as the IDL spells it, by variant index.
    pub const idl_values = [_][]const u8{ "default", "no-store", "reload", "no-cache", "force-cache", "only-if-cached" };
};
