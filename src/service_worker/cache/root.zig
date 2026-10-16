//! Cache Storage (Service Workers 5): a Browser's caches.
//!
//! - records.zig: a cached request and response, and their bytes.
//! - store.zig: the name to cache maps and request response lists in the
//!   Browser's store (the platform protocol's storage engine), Query Cache,
//!   Request Matches Cached Item and Batch Cache Operations - engine-free.
//! - api.zig: the steps of CacheStorage's and Cache's members, in a realm.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#cache-objects

pub const records = @import("records.zig");
pub const store = @import("store.zig");
pub const api = @import("api.zig");
